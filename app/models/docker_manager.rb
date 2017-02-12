# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('lib/exceptions')
require Rails.root.join('lib/docker_host_port_allocator')
require 'docker'
require 'fileutils'

class DockerManager < ContainerManager
  include ActionView::Helpers::DateHelper

  MIN_SUPPORTED_DOCKER_API_VERSION = '1.13'

  attr_reader :host_port_allocator, :plan_id, :image, :tag, :command, :entrypoint, :restart, :workdir,
              :environment, :expose_ports, :persistent_volumes, :user, :memory, :memory_swap,
              :cpu_shares, :privileged, :cap_adds, :cap_drops

  def initialize(attrs)
    super
    validate_docker_attrs(attrs)
    validate_docker_remote_api
    @host_port_allocator = DockerHostPortAllocator.instance

    @plan_id = attrs.fetch('plan_id')
    @image = attrs.fetch('image')
    @tag = attrs.fetch('tag', 'latest') || 'latest'
    @command = attrs.fetch('command', '')
    @entrypoint = attrs.fetch('entrypoint', nil)
    @restart = attrs.fetch('restart', 'always') || 'always'
    @workdir = attrs.fetch('workdir', nil)
    @environment = attrs.fetch('environment', []).compact || []
    @expose_ports = attrs.fetch('expose_ports', []).compact || []
    @persistent_volumes = attrs.fetch('persistent_volumes', []).compact || []
    @user = attrs.fetch('user', '') || ''
    @memory = attrs.fetch('memory', 0) || 0
    @memory_swap = attrs.fetch('memory_swap', 0) || 0
    @cpu_shares = attrs.fetch('cpu_shares', nil)
    @privileged = attrs.fetch('privileged', false)
    @cap_adds = attrs.fetch('cap_adds', []) || []
    @cap_drops = attrs.fetch('cap_drops', []) || []
  end

  def find(guid)
    Docker::Container.get(container_name(guid))
  rescue Docker::Error::NotFoundError
    nil
  end

  def can_allocate?(max_containers, max_plan_containers)
    unless max_containers.nil? || max_containers == 0
      containers = Docker::Container.all
      return false if containers.size >= max_containers
    end

    #unless max_plan_containers.nil? || max_plan_containers == 0
    #  plan_containers = containers.select do |container|
    #    # TODO: look up for plan guid?
    #    container.json['Config']['Image'] == "#{image}:#{tag}"
    #  end
    #  return false if plan_containers.size >= max_plan_containers
    #end

    true
  end

  def create(guid, parameters = {})
    Rails.logger.info("Creating Docker container `#{container_name(guid)}'...")
    container_create_opts = create_options(guid, parameters)
    Rails.logger.info("+-> Create options: #{container_create_opts.inspect}")
    container = Docker::Container.create(container_create_opts)

    container_start_opts = start_options(guid)
    Rails.logger.info("Starting Docker container `#{container_name(guid)}'...")
    Rails.logger.info("+-> Start options: #{container_start_opts.inspect}")
    container.start(container_start_opts)

    unless container_running?(container)
      container.remove(v: true, force: true) rescue nil #nop
      destroy_volumes(guid)
      raise Exceptions::BackendError, "Cannot start Docker container `#{container_name(guid)}'"
    end
  end

  def update(guid, parameters = {})
    Rails.logger.info("Updating Docker container `#{container_name(guid)}'...")
    unless container = find(guid)
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
    port_bindings = container.json['HostConfig']['PortBindings']
    container.stop('timeout' => 10)
    container.remove(v: true, force: true)

    container_create_opts = create_options(guid, parameters)
    Rails.logger.info("+-> Create/update options: #{container_create_opts.inspect}")
    container = Docker::Container.create(container_create_opts)

    container_start_opts = start_options(guid)
    container_start_opts['PortBindings'] = port_bindings
    Rails.logger.info("Starting Docker container `#{container_name(guid)}'...")
    Rails.logger.info("+-> Start options: #{container_start_opts.inspect}")
    container.start(container_start_opts)

    unless container_running?(container)
      container.remove(v: true, force: true) rescue nil #nop
      raise Exceptions::BackendError, "Cannot start Docker container `#{container_name(guid)}', volumes not deleted"
    end
  end

  def destroy(guid)
    Rails.logger.info("Destroying Docker container `#{container_name(guid)}'...")
    if container = find(guid)
      container.stop('timeout' => 10)
      container.remove(v: true, force: true)
      destroy_volumes(guid)
    else
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
  end

  def fetch_image
    Rails.logger.info("Fetching Docker image `#{image}:#{tag}'...")
    begin
      Docker::Image.create('fromImage' => "#{image}:#{tag}")
    rescue Exception => e
      Rails.logger.error("+-> Cannot fetch Docker image `#{image}:#{tag}': #{e.inspect}")
      raise Exceptions::BackendError, "Cannot fetch Docker image `#{image}:#{tag}"
    end
  end

  def update_all_containers
    all_containers.each do |container|
      guid = container.info['Config']['Labels']['instance_id']
      excluded_vars = env_vars(guid).map { |var| var.split('=').first }
      update(guid, envvars_from_container(container, excluded_vars))
    end
  end

  def service_credentials(guid)
    Rails.logger.info("Building credentials hash for container `#{container_name(guid)}'...")
    if container = find(guid)
      network_info = network_info(container)
      service_credentials = credentials.to_hash(guid, network_info['ip'], network_info['ports'])
      Rails.logger.info("+-> Credentials: " + service_credentials.inspect)
      service_credentials
    else
      raise Exceptions::NotFound, "Docker Container `#{container_name(guid)}' not found"
    end
  end

  def syslog_drain_url(guid)
    return nil unless syslog_drain_port

    if container = find(guid)
      Rails.logger.info("Building syslog_drain_url for container `#{container_name(guid)}'...")
      network_info = network_info(container)
      if port = network_info['ports'].fetch(syslog_drain_port, nil)
        url = "#{syslog_drain_protocol}://#{network_info['ip']}:#{port}"
        Rails.logger.info("+-> syslog_drain_url: #{url}")
      else
        url = nil
        Rails.logger.info("+-> syslog drain port #{syslog_drain_port} is not exposed")
      end
      url
    else
      raise Exceptions::NotFound, "Docker Container `#{container_name(guid)}' not found"
    end
  end

  def details(guid)
    Rails.logger.info("Building details hash for container `#{container_name(guid)}'...")
    if container = find(guid)
      container_json = container.json
      container_config = container_json.fetch('Config', {})
      container_state = container_json.fetch('State', {})
      container_hostconfig = container_json.fetch('HostConfig', {})
      container_network_settings = container_json.fetch('NetworkSettings', {})

      details = {
        'ID' => container_json['Id'],
        'Name' => container_json['Name'],
        'Image' => container_config['Image'],
        'Entrypoint' => container_config.fetch('Entrypoint', []).join(' '),
        'Command' => container_config.fetch('Cmd', []).join(' '),
        'Work Directory' => container_config['WorkingDir'],
        'Environment Variables' => container_config['Env'],
        'CPU Shares' => container_config['CpuShares'],
        'Memory' => container_config['Memory'],
        'Memory Swap' => container_config['MemorySwap'],
        'User' => container_config['User'],
        'Created' => "#{time_ago_in_words(Time.parse(container_json['Created']))} ago",
      }

      if container_running?(container)
        paused = container_state['Paused'] ? ' (Paused)' : ''
        details['Status'] = "Up for #{time_ago_in_words(Time.parse(container_state['StartedAt']))}" + paused
        details['Privileged'] = container_hostconfig['Privileged']
        details['IP Address'] = container_network_settings['IPAddress']
        details['Exposed Ports'] = network_info(container)['ports'].map { |cb, hp| "#{cb} -> #{hp}" }
        details['Exposed Volumes'] = container_hostconfig.fetch('Binds', [])
      else
        if container_state['ExitCode'] == 0
          details['Status'] = 'Stopped'
        else
          details['Status'] = "Exited (#{container_state['ExitCode']}) #{time_ago_in_words(Time.parse(container_state['FinishedAt']))} ago"
        end
      end

      Rails.logger.info("+-> details: #{details.inspect}")
      { 'Container Info' => details }
    else
      raise Exceptions::NotFound, "Docker Container `#{container_name(guid)}' not found"
    end
  end

  def processes(guid)
    Rails.logger.info("Retrieving processes for Docker container `#{container_name(guid)}'...")
    if container = find(guid)
      return [] unless container_running?(container)
      container.top
    else
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
  end

  def stdout(guid)
    Rails.logger.info("Retrieving STDOUT for Docker container `#{container_name(guid)}'...")
    if container = find(guid)
      container.logs(stdout: 1, timestamps: 1)
    else
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
  end

  def stderr(guid)
    Rails.logger.info("Retrieving STDERR for Docker container `#{container_name(guid)}'...")
    if container = find(guid)
      container.logs(stderr: 1, timestamps: 1)
    else
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
  end

  private

  def validate_docker_attrs(attrs)
    required_keys = %w(image plan_id)
    missing_keys = []

    required_keys.each do |key|
      missing_keys << "#{key}" unless attrs.key?(key)
    end

    unless missing_keys.empty?
      raise Exceptions::ArgumentError, "Missing Docker parameters: #{missing_keys.join(', ')}"
    end
  end

  def validate_docker_remote_api
    api_version = Docker.version.fetch('ApiVersion', '0')
    # Swarm returns API version with wrong key APIVersion instead of ApiVersion, so until
    # https://github.com/docker/swarm/issues/687 is solved and released, work around this
    if api_version == '0'
      api_version = Docker.version.fetch('APIVersion', '0')
    end
    unless api_version >= MIN_SUPPORTED_DOCKER_API_VERSION
      raise Exceptions::BackendError, "Docker Remote API version `#{api_version}' not supported"
    end
  rescue Excon::Errors::SocketError => e
    raise Exceptions::BackendError, "Unable to connect to the Docker Remote API `#{Docker.url}': #{e.message}"
  end

  def all_containers
    filters = {label: ["plan_id=#{plan_id}"]}.to_json
    Docker::Container.all(filters: filters).map do |container|
      Docker::Container.get(container.id)
    end
  end

  def container_running?(container)
    container.json.fetch('State', {}).fetch('Running', false)
  end

  def create_options(guid, parameters = {})
    {
      'name' => container_name(guid),
      'Hostname' => '',
      'Domainname' => '',
      'User' => user,
      'AttachStdin' => false,
      'AttachStdout' => true,
      'AttachStderr' => true,
      'Tty' => false,
      'OpenStdin' => false,
      'StdinOnce' => false,
      'Env' => env_vars(guid, parameters),
      'Cmd' => command.split(' '),
      'Entrypoint' => entrypoint,
      'Image' => "#{image.strip}:#{tag.strip}",
      'Labels' => {'plan_id' => plan_id, 'instance_id' => guid},
      'Volumes' => {},
      'WorkingDir' => workdir,
      'NetworkDisabled' => false,
      'ExposedPorts' => {},
      'HostConfig' => {
        'Binds' => volume_bindings(guid),
        'Memory' => convert_memory(memory),
        'MemorySwap' => convert_memory(memory_swap),
        'CpuShares' => cpu_shares,
        'PublishAllPorts' => false,
        'Privileged' => privileged,
      },
    }
  end

  def convert_memory(memory)
    return nil if memory.nil?
    return memory if memory.is_a?(Integer)

    unit = memory[-1, 1]
    case unit
    when 'b'
      memory.chop.to_i
    when 'k'
      memory.chop.to_i * 1024
    when 'm'
      memory.chop.to_i * 1024 * 1024
    when 'g'
      memory.chop.to_i * 1014 * 1024
    else
      memory
    end
  end

  def env_vars(guid, parameters = {})
    ev = build_custom_envvars
    ev << build_port_envvar(guid)
    ev << build_user_envvar(guid)
    ev << build_password_envvar(guid)
    ev << build_dbname_envvar(guid)
    ev << build_container_envvar(guid)
    ev << build_parameters_envvars(parameters)
    ev.flatten.compact
  end

  def build_custom_envvars
    environment.map do |env_var|
      ev = env_var.split('=')
      "#{ev.first.strip}=#{ev.last.strip}" unless ev.empty?
    end.compact
  end

  def build_port_envvar(guid)
    envvars = []
    # {"1234/tcp"=>[{"HostPort"=>"32768"}]}
    port_bindings(guid).each do |binding|
      container_port_tcp, host_port_hash = binding
      if container_port_tcp =~ /(\d+)\/tcp/
        container_port = $1
        host_port = host_port_hash[0]["HostPort"]
      end
      if container_port && host_port
        envvars << "DOCKER_HOST_PORT_#{container_port}=#{host_port}"
      end
    end
    envvars
  end

  def build_user_envvar(guid)
    if username_key = credentials.username_key
      "#{username_key}=#{credentials.username_value(guid)}"
    else
      nil
    end
  end

  def build_password_envvar(guid)
    if password_key = credentials.password_key
      "#{password_key}=#{credentials.password_value(guid)}"
    else
      nil
    end
  end

  def build_dbname_envvar(guid)
    if dbname_key = credentials.dbname_key
      "#{dbname_key}=#{credentials.dbname_value(guid)}"
    else
      nil
    end
  end

  def build_container_envvar(guid)
    base = ["NAME=#{container_name(guid)}"]
    Dir[File.join(Settings.container_env_var_dir, "*")].each do |env_var_file|
      env_var_name = File.basename(env_var_file)
      env_var_value = File.read(env_var_file).strip
      base << "#{env_var_name}=#{env_var_value}"
    end
    base
  end

  def build_parameters_envvars(parameters = {})
    parameters.map do |key, value|
      "#{key.to_s}=#{value.to_s}"
    end.compact
  end

  def envvars_from_container(container, exclude = [])
    container.info['Config']['Env'].reduce({}) do |map, var|
      key, value = var.split('=')
      map[key] = value unless exclude.include? key
      map
    end
  end

  def start_options(guid)
    {
      'Links' => [],
      'LxcConf' => {},
      'Memory' => convert_memory(memory),
      'MemorySwap' => convert_memory(memory_swap),
      'CpuShares' => cpu_shares,
      'PortBindings' => port_bindings(guid),
      'PublishAllPorts' => false,
      'Privileged' => privileged,
      'ReadonlyRootfs' => false,
      'VolumesFrom' => [],
      'CapAdd' => cap_adds,
      'CapDrop' => cap_drops,
      'RestartPolicy' => restart_policy,
      'Devices' => [],
      'Ulimits' => [],
    }
  end

  def volume_bindings(guid)
    return [] if persistent_volumes.nil? || persistent_volumes.empty?

    volumes = []
    persistent_volumes.each do |vol|
      directory = File.join(host_directory, container_name(guid), vol)
      FileUtils.mkdir_p(directory)
      FileUtils.chmod_R(0777, directory)
      volumes << "#{directory}:#{vol}"
    end
    volumes
  end

  def destroy_volumes(guid)
    return [] if persistent_volumes.nil? || persistent_volumes.empty?

    directory = File.join(host_directory, container_name(guid))
    FileUtils.remove_entry_secure(directory, true)
  end

  def host_directory
    Settings.host_directory
  end

  def port_bindings(guid)
    if expose_ports.empty?
      container = find(guid)
      image_expose_ports = container.json.fetch('Config', {}).fetch('ExposedPorts', {})
      Hash[image_expose_ports.map { |ep, _| [ep, [ host_port_binding(ep) ]] }]
    else
      Hash[expose_ports.map { |ep| [ep, [ host_port_binding(ep) ]] }]
    end
  end

  def host_port_binding(port)
    return {} unless Settings['allocate_docker_host_ports']
    return {} unless port

    p = port.split('/')
    protocol = p.last || 'tcp'
    return { 'HostPort' => host_port_allocator.allocate_host_port(protocol).to_s }
  end

  def network_info(container)
    info = {'ports' => {}}
    container.json.fetch('NetworkSettings', {}).fetch('Ports', {}).each do |cp, hp|
      unless hp.nil? || hp.empty?
        info['ip'] = hp.first['HostIp']
        info['ports'][cp] = hp.first['HostPort']
      end
    end
    # if we talk to a plain docker daemon (no swarm manager) we will see 0.0.0.0 as IP address
    # and should use the docker daemon IP address for the client to connect
    info['ip'] = Settings.external_ip if info['ip'] == '0.0.0.0'

    info
  end

  def restart_policy
    restart_args = restart.split(':')

    policy = { 'Name' => restart_args[0] }
    policy['MaximumRetryCount'] = restart_args[1].to_i if restart_args.size > 1

    policy
  end
end
