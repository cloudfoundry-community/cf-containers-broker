# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe ContainerManager do
  let(:subject) { described_class.new(attrs) }
  let(:attrs) {
    {
      'backend'           => 'my_backend',
      'credentials'       => {
        'username' => 'my-username',
      },
      'syslog_drain_port' => '514/udp',
      'syslog_drain_protocol' => 'syslog-tls',
    }
  }
  let(:guid) { 'guid' }
  let(:credentials) { double('Credentials') }

  before do
    allow(Credentials).to receive(:new).and_return(credentials)
  end

  describe '#initialize' do
    it 'sets the attributes correctly' do
      expect(subject.backend).to eq('my_backend')
      expect(subject.credentials).to eq(credentials)
      expect(subject.syslog_drain_port).to eq('514/udp')
      expect(subject.syslog_drain_protocol).to eq('syslog-tls')
    end

    context 'when mandatory keys are missing' do
      let(:attrs) { {} }

      it 'should raise a Exceptions::ArgumentError exception' do
        expect do
          subject
        end.to raise_error Exceptions::ArgumentError, 'Missing Container parameters: backend'
      end
    end

    context 'when optional keys are missing' do
      let(:attrs) {
        {
          'backend' => 'my_backend',
        }
      }

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
  end

  describe '#find' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.find(guid)
      end.to raise_error(Exceptions::NotImplemented, "`find' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#can_allocate?' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.can_allocate?(1,1 )
      end.to raise_error(Exceptions::NotImplemented, "`can_allocate?' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#create' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.create(guid)
      end.to raise_error(Exceptions::NotImplemented, "`create' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#destroy' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.destroy(guid)
      end.to raise_error(Exceptions::NotImplemented, "`destroy' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#fetch_image' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.fetch_image
      end.to raise_error(Exceptions::NotImplemented, "`fetch_image' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#service_credentials' do
    it 'should raise a NotImplemented Exception' do
      expect do
        subject.service_credentials(guid)
      end.to raise_error(Exceptions::NotImplemented, "`service_credentials' is not implemented by `#{subject.class.name}'")
    end
  end

  describe '#syslog_drain_url' do
    it 'should return nil' do
      expect(subject.syslog_drain_url(guid)).to be_nil
    end
  end

  describe '#details' do
    it 'should return nil' do
      expect(subject.details(guid)).to be_nil
    end
  end

  describe '#processes' do
    it 'should return nil' do
      expect(subject.processes(guid)).to be_nil
    end
  end

  describe '#stdout' do
    it 'should return nil' do
      expect(subject.stdout(guid)).to be_nil
    end
  end

  describe '#stderr' do
    it 'should return nil' do
      expect(subject.stderr(guid)).to be_nil
    end
  end
end
