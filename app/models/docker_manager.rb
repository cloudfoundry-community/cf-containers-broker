# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('lib/exceptions')
require 'docker'
require 'fileutils'

class DockerManager < ContainerManager
  include ActionView::Helpers::DateHelper

  MIN_SUPPORTED_DOCKER_API_VERSION = '1.13'

  attr_reader :image, :tag, :command, :entrypoint, :restart, :workdir, :environment, :expose_ports,
              :persistent_volumes, :user, :memory, :memory_swap, :cpu_shares, :privileged,
              :cap_adds, :cap_drops

  def initialize(attrs)
    super
    validate_docker_attrs(attrs)
    validate_docker_remote_api

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

  def create(guid)
    Rails.logger.info("Creating Docker container `#{container_name(guid)}'...")
    container_create_opts = create_options(guid)
    Rails.logger.info("+-> Create options: #{container_create_opts.inspect}")
    container = Docker::Container.create(container_create_opts)

    container_start_opts = start_options(guid)
    Rails.logger.info("Starting Docker container `#{container_name(guid)}'...")
    Rails.logger.info("+-> Start options: #{container_start_opts.inspect}")
    container.start(container_start_opts)

    unless container_running?(container)
      container.remove(v: true, force: true) rescue nil #nop
      raise Exceptions::BackendError, "Cannot start Docker container `#{container_name(guid)}'"
    end
  end

  def destroy(guid)
    Rails.logger.info("Destroying Docker container `#{container_name(guid)}'...")
    if container = find(guid)
      container.kill
      container.remove(v: true, force: true)
      destroy_volumes(guid)
    else
      raise Exceptions::NotFound, "Docker container `#{container_name(guid)}' not found"
    end
  end

  def fetch_image
    Rails.logger.info("Fetching Docker image `#{image}:#{tag}'...")
    begin
      Docker::Image.create('fromImage' => image, 'tag' => tag)
    rescue Exception => e
      Rails.logger.error("+-> Cannot fetch Docker image `#{image}:#{tag}': #{e.inspect}")
      raise Exceptions::BackendError, "Cannot fetch Docker image `#{image}:#{tag}"
    end
  end

  def service_credentials(guid)
    Rails.logger.info("Building credentials hash for container `#{container_name(guid)}'...")
    if container = find(guid)
      service_credentials = credentials.to_hash(guid, host_uri, bound_ports(container))
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
      if port = bound_ports(container).fetch(syslog_drain_port, nil)
        url = "#{syslog_drain_protocol}://#{host_uri}:#{port}"
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
        details['Exposed Ports'] = bound_ports(container).map { |cb, hp| "#{cb} -> #{hp}" }
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
    required_keys = %w(image)
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
    unless api_version >= MIN_SUPPORTED_DOCKER_API_VERSION
      raise Exceptions::BackendError, "Docker Remote API version `#{api_version}' not supported"
    end
  rescue Excon::Errors::SocketError => e
    raise Exceptions::BackendError, "Unable to connect to the Docker Remote API `#{Docker.url}': #{e.message}"
  end

  def container_running?(container)
    container.json.fetch('State', {}).fetch('Running', false)
  end

  def create_options(guid)
    {
      'name' => container_name(guid),
      'Hostname' => '',
      'User' => user,
      'Memory' => convert_memory(memory),
      'MemorySwap' => convert_memory(memory_swap),
      'CpuShares' => cpu_shares,
      'AttachStdin' => false,
      'AttachStdout' => true,
      'AttachStderr' => true,
      'PortSpecs' => nil,
      'Tty' => false,
      'OpenStdin' => false,
      'StdinOnce' => false,
      'Env' => env_vars(guid),
      'Cmd' => command.split(' '),
      'Entrypoint' => entrypoint,
      'Image' => "#{image.strip}:#{tag.strip}",
      'Volumes' => {},
      'WorkingDir' => workdir,
      'DisableNetwork' => false,
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

  def env_vars(guid)
    ev = build_custom_envvars
    ev << build_user_envvar(guid)
    ev << build_password_envvar(guid)
    ev << build_dbname_envvar(guid)
    ev.flatten.compact
  end

  def build_custom_envvars
    environment.map do |env_var|
      ev = env_var.split('=')
      "#{ev.first.strip}=#{ev.last.strip}" unless ev.empty?
    end.compact
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

  def start_options(guid)
    {
      'Binds' => volume_bindings(guid),
      'PortBindings' => port_bindings(guid),
      'PublishAllPorts' => false,
      'Privileged' => privileged,
      'RestartPolicy' => restart_policy,
      'CapAdd' => cap_adds,
      'CapDrop' => cap_drops,
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

  def host_port_allocator
    @host_port_allocator ||= HostPortAllocator.new(host_directory, 10000, 63000)
  end

  # Allocates the next available host port
  def allocate_host_port
    host_port_allocator.allocate_next_port
  end

  def port_bindings(guid)
    # 'PortBindings' => { '5000/tcp' => [{ 'HostPort' => '5000' }] }
    if expose_ports.empty?
      container = find(guid)
      image_expose_ports = container.json.fetch('Config', {}).fetch('ExposedPorts', {})
      Hash[image_expose_ports.map { |ep, _| [ep, [{'HostPort' => allocate_host_port.to_s}]] }]
    else
      Hash[expose_ports.map { |ep| [ep, [{'HostPort' => allocate_host_port.to_s}]] }]
    end
  end

  def bound_ports(container)
    ports = {}
    container.json.fetch('NetworkSettings', {}).fetch('Ports', {}).each do |cp, hp|
      ports[cp] = hp.first['HostPort'] unless hp.nil? || hp.empty?
    end
    ports
  end

  def restart_policy
    restart_args = restart.split(':')

    policy = { 'Name' => restart_args[0] }
    policy['MaximumRetryCount'] = restart_args[1].to_i if restart_args.size > 1

    policy
  end

  def host_uri
    Settings.external_ip
  end
end
