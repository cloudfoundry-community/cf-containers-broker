# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'
require 'excon'

describe DockerManager do
  let(:subject) { described_class.new(attrs) }
  let(:attrs) do
    {
      'plan_id' => 'plan_id',
      'backend' => 'docker',
      'image' => 'my-image',
      'tag' => 'latest',
      'command' => 'command1 command2',
      'entrypoint' => ['/bin/bash'],
      'workdir' => 'my-wordkdir',
      'restart' => restart,
      'environment' => ['USER=MY-USER'],
      'expose_ports' => [expose_port],
      'persistent_volumes' => [persistent_volume],
      'user' => 'my-user',
      'memory' => '512m',
      'memory_swap' => '256m',
      'cpu_shares' => 0.1,
      'privileged' => true,
      'cap_adds' => ['NET_ADMIN'],
      'cap_drops' => ['CHOWN'],
      'credentials' => {
        'username' => {
          'key' => username_key,
          'value' => username_value,
        },
        'password' => {
            'key' => password_key,
            'value' => password_value,
        },
        'dbname' => {
            'key' => dbname_key,
            'value' => dbname_value,
        },
      },
      'syslog_drain_port' => syslog_drain_port,
      'syslog_drain_protocol' => syslog_drain_protocol,
    }
  end
  let(:guid) { 'guid' }
  let(:container_name) { "#{DockerManager::CONTAINER_PREFIX}-#{guid}" }
  let(:container) { double('Container') }
  let(:username_key) { nil }
  let(:username_value) { 'MY-USERNAME' }
  let(:password_key) { nil }
  let(:password_value) { 'MY-PASSWORD' }
  let(:dbname_key) { nil }
  let(:dbname_value) { 'MY-DBNAME' }
  let(:credentials) { double('Credentials',
                             username_key: username_key,
                             password_key: password_key,
                             dbname_key: dbname_key) }
  let(:expose_port) { '1234/tcp' }
  let(:exposed_container_port) { 1234 }
  let(:syslog_drain_port) { '512/udp' }
  let(:syslog_drain_protocol) { 'syslog-tls' }
  let(:persistent_volume) { '/data' }
  let(:restart) { 'on-failure:5' }
  let(:api_version) { DockerManager::MIN_SUPPORTED_DOCKER_API_VERSION }
  let(:host_post_allocator) { double('DockerHostPortAllocator') }
  let(:host_port) { 32768 }

  before do
    allow(Docker).to receive(:version).and_return({ 'ApiVersion' => api_version })
    allow(Credentials).to receive(:new).and_return(credentials)
    allow(credentials).to receive(:username_value).with(guid).and_return(username_value)
    allow(credentials).to receive(:password_value).with(guid).and_return(password_value)
    allow(credentials).to receive(:dbname_value).with(guid).and_return(dbname_value)
    allow(DockerHostPortAllocator).to receive(:instance).and_return(host_post_allocator)
    allow(host_post_allocator).to receive(:allocate_host_port).with('tcp').and_return(host_port)
  end

  describe '#initialize' do
    it 'sets the attributes correctly' do
      expect(subject.backend).to eq('docker')
      expect(subject.image).to eq('my-image')
      expect(subject.command).to eq('command1 command2')
      expect(subject.entrypoint).to eq(['/bin/bash'])
      expect(subject.workdir).to eq('my-wordkdir')
      expect(subject.restart).to eq(restart)
      expect(subject.expose_ports).to eq(['1234/tcp'])
      expect(subject.environment).to eq(["USER=MY-USER"])
      expect(subject.persistent_volumes).to eq(['/data'])
      expect(subject.user).to eq('my-user')
      expect(subject.memory).to eq('512m')
      expect(subject.memory_swap).to eq('256m')
      expect(subject.cpu_shares).to eq(0.1)
      expect(subject.privileged).to be_truthy
      expect(subject.cap_adds).to eq(['NET_ADMIN'])
      expect(subject.cap_drops).to eq(['CHOWN'])
      expect(subject.credentials).to eq(credentials)
      expect(subject.syslog_drain_port).to eq(syslog_drain_port)
      expect(subject.syslog_drain_protocol).to eq(syslog_drain_protocol)
    end

    context 'when mandatory keys are missing' do
      it 'should raise a Exceptions::ArgumentError exception' do
        expect do
          described_class.new({ 'backend' => 'docker', 'plan_id' => 'plan_id'})
        end.to raise_error Exceptions::ArgumentError, 'Missing Docker parameters: image'
      end
    end

    context 'when optional keys are missing' do
      let(:attrs) do
        {
          'backend'=> 'docker',
          'image' => 'my-image',
          'plan_id' => 'plan_id',
        }
      end

      it 'sets the tag field to latest' do
        expect(subject.tag).to eql('latest')
      end

      it 'sets the command field to an empty string' do
        expect(subject.command).to eql('')
      end

      it 'sets the entrypoint field to nil' do
        expect(subject.entrypoint).to be_nil
      end

      it 'sets the workdir field to nil' do
        expect(subject.workdir).to be_nil
      end

      it 'sets the restart field to always' do
        expect(subject.restart).to eq('always')
      end

      it 'sets the environment field to an empty array' do
        expect(subject.environment).to eq([])
      end

      it 'sets the expose_ports field to an empty array' do
        expect(subject.expose_ports).to eq([])
      end

      it 'sets the persistent_volumes field to an empty array' do
        expect(subject.persistent_volumes).to eq([])
      end

      it 'sets the user field to an empty string' do
        expect(subject.user).to eq('')
      end

      it 'sets the memory field to 0' do
        expect(subject.memory).to eq(0)
      end

      it 'sets the memory_swap field to 0l' do
        expect(subject.memory_swap).to eq(0)
      end

      it 'sets the cpu_shares field to nil' do
        expect(subject.cpu_shares).to be_nil
      end

      it 'sets the privileged field to false' do
        expect(subject.privileged).to be_falsey
      end

      it 'sets the cap_adds field to an empty array' do
        expect(subject.cap_adds).to eq([])
      end

      it 'sets the cap_drops field to an empty array' do
        expect(subject.cap_drops).to eq([])
      end

      it 'sets the credentials field to a Credentials object' do
        expect(subject.credentials).to eq(credentials)
      end

      it 'sets the syslog_drain_port field to nil' do
        expect(subject.syslog_drain_port).to be_nil
      end

      it 'sets the syslog_drain_protocol field to syslog' do
        expect(subject.syslog_drain_protocol).to eq('syslog')
      end
    end

    context 'when unable to connect to the Docker Remote API' do
      let(:docker_url) { 'unix://var/run/docker.sock' }

      before do
        allow(Docker).to receive(:version).and_raise(Excon::Errors::SocketError.new(Exception.new('socket error')))
      end

      it 'should raise a Exceptions::BackendError exception' do
        expect do
          expect(Docker).to receive(:url).and_return(docker_url)
          described_class.new(attrs)
        end.to raise_error(Exceptions::BackendError,
                           "Unable to connect to the Docker Remote API `#{docker_url}': socket error (Exception)")
      end
    end

    context 'when the Docker Remote API version is not supported' do
      let(:api_version) { '1.10' }

      it 'should raise a Exceptions::BackendError exception' do
        expect do
          described_class.new(attrs)
        end.to raise_error(Exceptions::BackendError, "Docker Remote API version `#{api_version}' not supported")
      end
    end
  end

  describe '#find' do
    it 'should return the container' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(subject.find(guid)).to eql(container)
    end

    context 'when the container does not exists' do
      it 'should return nil' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect(subject.find(guid)).to be_nil
      end
    end

    context 'when the Docker API raises an exception' do
      it 'should raise the same exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::IOError)
        expect do
          subject.find(guid)
        end.to raise_error(Docker::Error::IOError)
      end
    end
  end

  describe '#can_allocate?' do
    context 'when the number of existing containers does not exceed max_containers' do
      it 'should return true' do
        expect(Docker::Container).to receive(:all).and_return(['Container_1'])
        expect(subject.can_allocate?(10, 1)).to be_truthy
      end
    end

    context 'when the number of existing containers exceeds max_containers' do
      it 'should return false' do
        expect(Docker::Container).to receive(:all).and_return(['Container_1'])
        expect(subject.can_allocate?(1, 1)).to be_falsey
      end
    end

    context 'when max_containers is not set' do
      it 'should return true' do
        expect(subject.can_allocate?(nil, nil)).to be_truthy
      end
    end

    context 'when max_containers is 0' do
      it 'should return true' do
        expect(subject.can_allocate?(0, 0)).to be_truthy
      end
    end
  end

  describe 'crud' do
    let(:container_create_opts) {
      {
        'name' => container_name,
        'Hostname' => '',
        'Domainname' => '',
        'User' => 'my-user',
        'AttachStdin' => false,
        'AttachStdout' => true,
        'AttachStderr' => true,
        'Tty' => false,
        'OpenStdin' => false,
        'StdinOnce' => false,
        'Env' => env_vars,
        'Cmd' => ['command1', 'command2'],
        'Entrypoint' => ['/bin/bash'],
        'Image' => 'my-image:latest',
        'Labels' => {'plan_id' => 'plan_id', 'instance_id' => guid},
        'Volumes' => {},
        'WorkingDir' => 'my-wordkdir',
        'NetworkDisabled' => false,
        'ExposedPorts' => {},
        'HostConfig' => {
          'Binds' => binds,
          'Memory' => 512 * 1024 * 1024,
          'MemorySwap' => 256 * 1024 * 1024,
          'CpuShares' => 0.1,
          'PublishAllPorts' => false,
          'Privileged' => true,
        },
      }
    }
    let(:container_start_opts) {
      {
        'Links' => [],
        'LxcConf' => {},
        'Memory' => 512 * 1024 * 1024,
        'MemorySwap' => 256 * 1024 * 1024,
        'CpuShares' => 0.1,
        'PortBindings' => port_bindings,
        'PublishAllPorts' => false,
        'Privileged' => true,
        'ReadonlyRootfs' => false,
        'VolumesFrom' => [],
        'CapAdd' => ['NET_ADMIN'],
        'CapDrop' => ['CHOWN'],
        'RestartPolicy' => {
          'Name' => 'on-failure',
          'MaximumRetryCount' => 5,
        },
        'Devices' => [],
        'Ulimits' => [],
      }
    }
    let(:env_vars) { ['USER=MY-USER', "NAME=#{container_name}"] }
    let(:binds) { [] }
    let(:port_bindings) { { expose_port => [{ 'HostPort' => host_port.to_s }] } }
    let(:persistent_volume) { nil }
    let(:container_running) { true }
    let(:container_state) {
      {
        'State' => { 'Running' => container_running },
        'Config' => { 'ExposedPorts' => { expose_port => {} }},
      }
    }
    describe '#create' do

      it 'should create and start a container' do
        expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
        expect(container).to receive(:start).with(container_start_opts)
        expect(container).to receive(:json).and_return(container_state)
        subject.create(guid)
      end

      context 'when container cannot be started' do
        let(:container_running) { false }

        it 'should remove the failed container' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          expect(container).to receive(:remove).with(v: true, force: true)
          expect do
            subject.create(guid)
          end.to raise_error(Exceptions::BackendError, "Cannot start Docker container `#{container_name}'")
        end
      end

      context 'when there are credentials' do
        before do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
        end

        context 'with a username key' do
          let(:username_key) { 'USERNAME-KEY' }
          let(:env_vars) { ['USER=MY-USER',
            "#{username_key}=#{username_value}",
            "NAME=#{container_name}"] }

          it 'should inject the username environment variable' do
            subject.create(guid)
          end
        end

        context 'with a password key' do
          let(:password_key) { 'PASSWORD-KEY' }
          let(:env_vars) { ['USER=MY-USER',
            "#{password_key}=#{password_value}",
            "NAME=#{container_name}"] }

          it 'should inject the password environment variable' do
            subject.create(guid)
          end
        end

        context 'with a dbname key' do
          let(:dbname_key) { 'DBNAME-KEY' }
          let(:env_vars) { ['USER=MY-USER',
            "#{dbname_key}=#{dbname_value}",
            "NAME=#{container_name}"] }

          it 'should inject the dbname environment variable' do
            subject.create(guid)
          end
        end
      end

      context 'when there are no exposed ports' do
        let(:expose_port) { nil }
        let(:port_bindings) { { expose_port => [{}] } }
        let(:env_vars) { ['USER=MY-USER', "NAME=#{container_name}"] }

        it 'should expose the container image exposed ports' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
          expect(container).to receive(:json).at_least(2).and_return(container_state)
          expect(container).to receive(:start).with(container_start_opts)
          subject.create(guid)
        end
      end

      context 'when there are persistent volumes' do
        let(:persistent_volume) { '/data' }
        let(:binds) { ["/tmp/#{container_name}#{persistent_volume}:#{persistent_volume}"] }

        it 'should create a host directory and mount it to the container' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(Settings).to receive(:host_directory).and_return('/tmp')
          expect(FileUtils).to receive(:mkdir_p).with("/tmp/#{container_name}#{persistent_volume}")
          expect(FileUtils).to receive(:chmod_R).with(0777, "/tmp/#{container_name}#{persistent_volume}")
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid)
        end
      end

      context 'when restart policy does not include a retry count' do
        let(:restart) { 'no' }
        let(:container_start_opts) {
          {
            'Links' => [],
            'LxcConf' => {},
            'Memory' => 512 * 1024 * 1024,
            'MemorySwap' => 256 * 1024 * 1024,
            'CpuShares' => 0.1,
            'PortBindings' => port_bindings,
            'PublishAllPorts' => false,
            'Privileged' => true,
            'ReadonlyRootfs' => false,
            'VolumesFrom' => [],
            'CapAdd' => ['NET_ADMIN'],
            'CapDrop' => ['CHOWN'],
            'RestartPolicy' => {
              'Name' => restart,
            },
            'Devices' => [],
            'Ulimits' => [],
          }
        }

        it 'should not add it at the start options' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid)
        end
      end

      context 'when allocate_docker_host_ports is not set' do
        let(:port_bindings) { { expose_port => [{}] } }
        let(:env_vars) { ['USER=MY-USER', "NAME=#{container_name}"] }

        before do
          expect(Settings).to receive(:[]).with('allocate_docker_host_ports').and_return(false)
          expect(Settings).to receive(:[]).with('enable_host_port_envvar').and_return(nil)
        end

        it 'should not add host port bindings when starting a container' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid)
        end
      end

      context 'when there are container env vars in files' do
        let(:tmp_envdir) { "/tmp/container_env_var_dir" }
        let(:env_vars) { ['USER=MY-USER',
          "NAME=#{container_name}",
          'lower_case=lower-value',
          'UPPER_CASE=1234'] }

        before do
          FileUtils.rm_rf(tmp_envdir)
          FileUtils.mkdir_p(tmp_envdir)
          expect(Settings).to receive(:container_env_var_dir).and_return(tmp_envdir)
        end

        it 'should load files into container env vars' do
          File.open(File.join(tmp_envdir, "lower_case"), "w") { |f| f << "lower-value\n" }
          File.open(File.join(tmp_envdir, "UPPER_CASE"), "w") { |f| f << "1234" }

          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid)
        end
      end

      context 'when badly configured Settings.container_env_var_dir' do
        before do
          expect(Settings).to receive(:container_env_var_dir).and_return("/path/not/exists")
        end

        it 'should not fail if Settings.container_env_var_dir does not exist' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid)
        end
      end

      context 'when there are service arbitrary parameters' do
        let(:parameters) { { 'foo' => 'bar', 'bar' => 'foo' } }
        let(:env_vars) { ['USER=MY-USER',
          "NAME=#{container_name}",
          'foo=bar', 'bar=foo'] }

        it 'should pass the arbitrary parameters as environment variables' do
          expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
          expect(container).to receive(:start).with(container_start_opts)
          expect(container).to receive(:json).and_return(container_state)
          subject.create(guid, parameters)
        end
      end
    end

    describe '#update' do
      let(:persistent_volume) { '/data' }
      let(:binds) { ["/tmp/#{container_name}#{persistent_volume}:#{persistent_volume}"] }
      let(:port_bindings) { {"5432/tcp"=>[{"HostIp"=>"", "HostPort"=>"55555"}]} }

      it 'should stop then recreate the container with existing persistent data' do
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:json).and_return({
          'HostConfig' => {'PortBindings' => port_bindings}})
        expect(container).to receive(:stop)
        expect(container).to receive(:remove).with(v: true, force: true)

        expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
        # idempotently recreates existing volume folder on host machine
        expect(Settings).to receive(:host_directory).and_return('/tmp')
        expect(FileUtils).to receive(:mkdir_p).with("/tmp/#{container_name}#{persistent_volume}")
        expect(FileUtils).to receive(:chmod_R).with(0777, "/tmp/#{container_name}#{persistent_volume}")

        container_start_opts['PortBindings'] = port_bindings
        expect(container).to receive(:start).with(container_start_opts)
        expect(container).to receive(:json).and_return(container_state)

        subject.update(guid)
      end

      context 'when the container does not exists' do
        it 'should raise an Exception' do
          expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
          expect do
            subject.update(guid)
          end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
        end
      end
    end
  end

  describe '#destroy' do
    it 'should stop and remove the container and delete any persistent data' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:stop)
      expect(container).to receive(:remove).with(v: true, force: true)
      expect(Settings).to receive(:host_directory).and_return('/tmp')
      expect(FileUtils).to receive(:remove_entry_secure).with("/tmp/#{container_name}", true)
      subject.destroy(guid)
    end

    context 'when the container does not exists' do
      it 'should raise an Exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect do
          subject.destroy(guid)
        end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
      end
    end

    context 'when container does not have a volume attached' do
      let(:persistent_volume) { nil }

      it 'should not delete any persistent data' do
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:stop)
        expect(container).to receive(:remove).with(v: true, force: true)
        expect(Settings).to_not receive(:host_directory)
        expect(FileUtils).to_not receive(:remove_entry_secure)
        subject.destroy(guid)
      end
    end
  end

  describe '#fetch_image' do
    it 'should fetch the image' do
      expect(Docker::Image).to receive(:create).with('fromImage' => 'my-image:latest')
      subject.fetch_image
    end

    context 'when it cannot fetch the image' do
      it 'should raise an Exception' do
        expect(Docker::Image).to receive(:create)
                                 .with('fromImage' => 'my-image:latest')
                                 .and_raise(Exceptions::NotFound)
        expect do
          subject.fetch_image
        end.to raise_error(Exceptions::BackendError, "Cannot fetch Docker image `my-image:latest")
      end
    end
  end

  describe '#update_all_containers' do
    let(:containers) { [ double('c1', id: 'c1'), double('c2', id: 'c2')] }
    let(:container1_info) do
      old_image_info = { 'Config' => {
        'Labels' => { 'instance_id' => 'instance-id1' }, 'Env' => []}}
    end
    let(:container2_info) do
      old_image_info = { 'Config' => {
        'Labels' => { 'instance_id' => 'instance-id2' }, 'Env' => []}}
    end
    let(:container1) { double('container1', info: container1_info) }
    let(:container2) { double('container2', info: container2_info) }

    before do
      allow(Docker::Container).to receive(:all) { containers }
      allow(Docker::Container).to receive(:get).with('c1') { container1 }
      allow(Docker::Container).to receive(:get).with('c2') { container2 }
    end

    it 'calls update for each container' do
      expect(subject).to receive(:update).with('instance-id1', {})
      expect(subject).to receive(:update).with('instance-id2', {})

      subject.update_all_containers
    end

    it 'preserves environment variables that are not provided via plan attrs' do
      provided_var = 'USER=USER'
      not_provided_var = 'FOO=BAR'
      info_with_env_vars = {
        'Config' => {
          'Labels' => { 'instance_id' => 'instance-id1' },
          'Env' => [provided_var, not_provided_var]}}

      allow(container1).to receive(:info) { info_with_env_vars }

      expect(subject).to receive(:update).with('instance-id1', {'FOO' => 'BAR'})
      expect(subject).to receive(:update).with('instance-id2', {})

      subject.update_all_containers
    end
  end

  describe '#service_credentials' do
    # TODO
  end

  describe '#syslog_drain_url' do
    let(:settings_host_ip) { '1.2.3.4' }
    let(:exposed_host_port) { '2345' }
    let(:exposed_host_ip) { '0.0.0.0' }
    let(:container_state) {
      {
        'NetworkSettings' => { 'Ports' => { syslog_drain_port => [{'HostIp' => exposed_host_ip, 'HostPort' => exposed_host_port}] }},
      }
    }

    it 'should return the syslog drain url' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:json).and_return(container_state)
      expect(Settings).to receive(:external_ip).and_return('1.2.3.4')
      expect(subject.syslog_drain_url(guid)).to eq("#{syslog_drain_protocol}://#{settings_host_ip}:#{exposed_host_port}")
    end

    context 'when the syslog drain port is not exposed' do
      let(:exposed_host_ip) { '1.2.3.4' }

      it 'should return the syslog drain url with the correct host ip' do
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:json).and_return(container_state)
        expect(Settings).to_not receive(:external_ip)
        expect(subject.syslog_drain_url(guid)).to eq("#{syslog_drain_protocol}://#{exposed_host_ip}:#{exposed_host_port}")
      end
    end

    context 'when the syslog drain port is not exposed' do
      let(:exposed_host_port) { nil }

      it 'should not return the syslog drain url' do
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:json).and_return(container_state)
        expect(subject.syslog_drain_url(guid)).to be_nil
      end
    end

    context 'when there is no syslog drain port' do
      let(:syslog_drain_port) { nil }

      it 'should not return the syslog drain url' do
        expect(subject.syslog_drain_url(guid)).to be_nil
      end
    end

    context 'when the container does not exists' do
      it 'should raise an Exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect do
          subject.processes(guid)
        end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
      end
    end
  end

  describe '#details' do
    # TODO
  end

  describe '#processes' do
    it 'should retrieve the top processes' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:json).and_return({ 'State' => { 'Running' => true } })
      expect(container).to receive(:top).and_return(['PROCESSES'])
      expect(subject.processes(guid)).to eq(['PROCESSES'])
    end

    context 'when the container is not running' do
      it 'should return an empty array' do
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:json).and_return({ 'State' => { 'Running' => false } })
        expect(container).to_not receive(:top)
        expect(subject.processes(guid)).to eq([])
      end
    end

    context 'when the container does not exists' do
      it 'should raise an Exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect do
          subject.processes(guid)
        end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
      end
    end
  end

  describe '#stdout' do
    it 'should retrieve the STDOUT logs' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:logs).with(stdout: 1, timestamps: 1).and_return(['STDOUT'])
      expect(subject.stdout(guid)).to eq(['STDOUT'])
    end

    context 'when the container does not exists' do
      it 'should raise an Exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect do
          subject.stdout(guid)
        end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
      end
    end
  end

  describe '#stderr' do
    it 'should retrieve the STDERR logs' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:logs).with(stderr: 1, timestamps: 1).and_return(['STDERR'])
      expect(subject.stderr(guid)).to eq(['STDERR'])
    end

    context 'when the container does not exists' do
      it 'should raise an Exception' do
        expect(Docker::Container).to receive(:get).with(container_name).and_raise(Docker::Error::NotFoundError)
        expect do
          subject.stderr(guid)
        end.to raise_error(Exceptions::NotFound, "Docker container `#{container_name}' not found")
      end
    end
  end
end
