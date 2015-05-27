# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'
require 'excon'

describe DockerManager do
  let(:subject) { described_class.new(attrs) }
  let(:attrs) do
    {
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
  let(:container_expose_port) { '5678/tcp' }
  let(:syslog_drain_port) { '512/udp' }
  let(:syslog_drain_protocol) { 'syslog-tls' }
  let(:persistent_volume) { '/data' }
  let(:restart) { 'on-failure:5' }
  let(:api_version) { DockerManager::MIN_SUPPORTED_DOCKER_API_VERSION }
  let(:allocated_host_port) { 10000 }

  before do
    allow(Docker).to receive(:version).and_return({ 'ApiVersion' => api_version })
    allow(Credentials).to receive(:new).and_return(credentials)
    allow(credentials).to receive(:username_value).with(guid).and_return(username_value)
    allow(credentials).to receive(:password_value).with(guid).and_return(password_value)
    allow(credentials).to receive(:dbname_value).with(guid).and_return(dbname_value)
    expect(subject).to receive(:allocate_host_port).and_return(10000).at_most(:once)
  end

  describe '#initialize' do
    it 'sets the attributes correctly' do
      expect(subject.backend).to eq('docker')
      expect(subject.image).to eq('my-image')
      expect(subject.command).to eq('command1 command2')
      expect(subject.entrypoint).to eq(['/bin/bash'])
      expect(subject.workdir).to eq('my-wordkdir')
      expect(subject.restart).to eq(restart)
      expect(subject.environment).to eq(['USER=MY-USER'])
      expect(subject.expose_ports).to eq(['1234/tcp'])
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
          described_class.new({ 'backend' => 'docker' })
        end.to raise_error Exceptions::ArgumentError, 'Missing Docker parameters: image'
      end
    end

    context 'when optional keys are missing' do
      let(:attrs) do
        {
          'backend'=> 'docker',
          'image' => 'my-image',
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

  describe '#create' do
    let(:container_create_opts) {
      {
        'name' => container_name,
        'Hostname' => '',
        'User' => 'my-user',
        'Memory' => 512 * 1024 * 1024,
        'MemorySwap' => 256 * 1024 * 1024,
        'CpuShares' => 0.1,
        'AttachStdin' => false,
        'AttachStdout' => true,
        'AttachStderr' => true,
        'PortSpecs' => nil,
        'Tty' => false,
        'OpenStdin' => false,
        'StdinOnce' => false,
        'Env' => env_vars,
        'Cmd' => ['command1', 'command2'],
        'Entrypoint' => ['/bin/bash'],
        'Image' => 'my-image:latest',
        'Volumes' => {},
        'WorkingDir' => 'my-wordkdir',
        'DisableNetwork' => false,
      }
    }
    let(:container_start_opts) {
      {
        'Binds' => binds,
        'PortBindings' => port_bindings,
        'PublishAllPorts' => false,
        'Privileged' => true,
        'RestartPolicy' => {
          'Name' => 'on-failure',
          'MaximumRetryCount' => 5,
        },
        'CapAdd' => ['NET_ADMIN'],
        'CapDrop' => ['CHOWN'],
      }
    }
    let(:env_vars) { ['USER=MY-USER'] }
    let(:binds) { [] }
    let(:port_bindings) { { expose_port => [{'HostPort' => '10000'}] } }
    let(:persistent_volume) { nil }
    let(:container_running) { true }
    let(:container_state) {
      {
        'State' => { 'Running' => container_running },
        'Config' => { 'ExposedPorts' => { container_expose_port => [{'HostPort' => '10000'}] }},
      }
    }

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
        let(:env_vars) { ['USER=MY-USER', "#{username_key}=#{username_value}"] }

        it 'should inject the username environment variable' do
          subject.create(guid)
        end
      end

      context 'with a password key' do
        let(:password_key) { 'PASSWORD-KEY' }
        let(:env_vars) { ['USER=MY-USER', "#{password_key}=#{password_value}"] }

        it 'should inject the password environment variable' do
          subject.create(guid)
        end
      end

      context 'with a dbname key' do
        let(:dbname_key) { 'DBNAME-KEY' }
        let(:env_vars) { ['USER=MY-USER', "#{dbname_key}=#{dbname_value}"] }

        it 'should inject the dbname environment variable' do
          subject.create(guid)
        end
      end
    end

    context 'when there are no exposed ports' do
      let(:expose_port) { nil }
      let(:port_bindings) { { container_expose_port => [{'HostPort' => '10000'}] } }

      it 'should expose the container image exposed ports' do
        expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
        expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
        expect(container).to receive(:start).with(container_start_opts)
        expect(container).to receive(:json).twice.and_return(container_state)
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
            'Binds' => binds,
            'PortBindings' => port_bindings,
            'PublishAllPorts' => false,
            'Privileged' => true,
            'RestartPolicy' => {
              'Name' => restart,
            },
            'CapAdd' => ['NET_ADMIN'],
            'CapDrop' => ['CHOWN'],
        }
      }

      it 'should not add it at the start options' do
        expect(Docker::Container).to receive(:create).with(container_create_opts).and_return(container)
        expect(container).to receive(:start).with(container_start_opts)
        expect(container).to receive(:json).and_return(container_state)
        subject.create(guid)
      end
    end
  end

  describe '#destroy' do
    it 'should kill and remove the container and delete any persistent data' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:kill)
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
        expect(container).to receive(:kill)
        expect(container).to receive(:remove).with(v: true, force: true)
        expect(Settings).to_not receive(:host_directory)
        expect(FileUtils).to_not receive(:remove_entry_secure)
        subject.destroy(guid)
      end
    end
  end

  describe '#fetch_image' do
    it 'should fetch the image' do
      expect(Docker::Image).to receive(:create).with('fromImage' => 'my-image', 'tag' => 'latest')
      subject.fetch_image
    end

    context 'when it cannot fetch the image' do
      it 'should raise an Exception' do
        expect(Docker::Image).to receive(:create)
                                 .with('fromImage' => 'my-image', 'tag' => 'latest')
                                 .and_raise(Exceptions::NotFound)
        expect do
          subject.fetch_image
        end.to raise_error(Exceptions::BackendError, "Cannot fetch Docker image `my-image:latest")
      end
    end
  end

  describe '#service_credentials' do
    # TODO
  end

  describe '#syslog_drain_url' do
    let(:exposed_host_port) { '2345' }
    let(:container_state) {
      {
        'NetworkSettings' => { 'Ports' => { syslog_drain_port => [{'HostPort' => exposed_host_port}] }},
      }
    }

    it 'should return the syslog drain url' do
      expect(Docker::Container).to receive(:get).with(container_name).and_return(container)
      expect(container).to receive(:json).and_return(container_state)
      expect(subject.syslog_drain_url(guid)).to eq("#{syslog_drain_protocol}://127.0.0.1:#{exposed_host_port}")
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
