# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Plan do
  let(:subject) { described_class }
  let(:docker_manager) { double('DockerManager') }
  let(:plan) do
    described_class.build(
      'id'                => 'plan_id',
      'name'              => 'plan_name',
      'description'       => 'plan_description',
      'metadata'          => {
        'meta_key' => 'meta_value',
      },
      'free'              => false,
      'max_containers'    => 5,
      'credentials'       => {
        'username' => 'my-username',
      },
      'syslog_drain_port' => '514/udp',
      'syslog_drain_protocol' => 'syslog-tls',
      'container'         => {
        'backend' => 'docker',
      },
    )
  end

  before do
    allow(DockerManager).to receive(:new).and_return(docker_manager)
  end

  describe '#build' do
    it 'sets the attributes correctly' do
      expect(plan.id).to eq('plan_id')
      expect(plan.name).to eq('plan_name')
      expect(plan.description).to eq('plan_description')
      expect(plan.metadata).to eq({ 'meta_key' => 'meta_value' })
      expect(plan.free).to eq(false)
      expect(plan.max_containers).to eq(5)
      expect(plan.credentials).to eq({ 'username' => 'my-username' })
      expect(plan.syslog_drain_port).to eq('514/udp')
      expect(plan.syslog_drain_protocol).to eq('syslog-tls')
      expect(plan.container_manager).to eq(docker_manager)
    end

    context 'when container backend is not supported' do
      it 'raises an exception' do
        expect do
          described_class.build(
            'id'          => 'plan_id',
            'name'        => 'plan_name',
            'description' => 'plan_description',
            'container'   => {
              'backend' => 'not-supported',
            },
          )
          end.to raise_error(Exceptions::NotSupported, "Could not load Container Manager for backend `not-supported'")
      end
    end

    context 'when mandatory keys are missing' do
      it 'should raise a Exceptions::ArgumentError exception' do
        expect do
          described_class.build({})
        end.to raise_error Exceptions::ArgumentError, 'Missing Plan parameters: id, name, description, container'
      end
    end

    context 'when optional keys are missing' do
      let(:plan) do
        described_class.build(
          'id'          => 'plan_id',
          'name'        => 'plan_name',
          'description' => 'plan_description',
          'container'   => {
            'backend' => 'docker',
          },
        )
      end

      it 'sets the metadata field to nil' do
        expect(plan.metadata).to be_nil
      end

      it 'sets the free field to true' do
        expect(plan.free).to be_truthy
      end

      it 'sets the max_containers field to nil' do
        expect(plan.max_containers).to be_nil
      end

      it 'sets the credentials field to an empty Hash' do
        expect(plan.credentials).to eql({})
      end

      it 'sets the syslog_drain_port field to nil' do
        expect(plan.syslog_drain_port).to be_nil
      end

      it 'sets the syslog_drain_protocol field to syslog' do
        expect(plan.syslog_drain_protocol).to eq('syslog')
      end
    end
  end

  describe '#to_hash' do
    it 'contains the correct values' do
      plan_hash = plan.to_hash

      expect(plan_hash.fetch('id')).to eq('plan_id')
      expect(plan_hash.fetch('name')).to eq('plan_name')
      expect(plan_hash.fetch('description')).to eq('plan_description')
      expect(plan_hash.fetch('metadata')).to eq({ 'meta_key' => 'meta_value' })
      expect(plan_hash.fetch('free')).to eq(false)
    end
  end
end
