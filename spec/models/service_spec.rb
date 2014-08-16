# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Service do
  let(:subject) { described_class }
  let(:plan) { double('Plan', to_hash: 'plan-hash') }
  let(:service) do
    described_class.build(
    'id'               => 'service_id',
    'name'             => 'service_name',
    'description'      => 'service_description',
    'bindable'         => false,
    'tags'             => [
      'tag',
    ],
    'metadata'         => {
      'meta_key' => 'meta_value',
    },
    'requires'         => [
      'syslog_drain',
    ],
    'plans'            => [
      double('Plan')
    ],
    'dashboard_client' => {
      'id'           => 'client-id',
      'secret'       => 'client-secret',
      'redirect_uri' => 'https://broker.10.0.0.1.xip.io/manage/auth/cloudfoundry/callback',
    },
  )
  end

  before do
    allow(Plan).to receive(:build).and_return(plan)
  end

  describe '#build' do
    it 'sets the attributes correctly' do
      expect(service.id).to eq('service_id')
      expect(service.name).to eq('service_name')
      expect(service.description).to eq('service_description')
      expect(service.bindable).to be_falsey
      expect(service.tags).to eq(['tag'])
      expect(service.metadata).to eq({ 'meta_key' => 'meta_value' })
      expect(service.requires).to eq(['syslog_drain'])
      expect(service.plans).to eq([plan])
      expect(service.dashboard_client).to eql({
        'id'           => 'client-id',
        'secret'       => 'client-secret',
        'redirect_uri' => 'https://broker.10.0.0.1.xip.io/manage/auth/cloudfoundry/callback',
      })
    end

    context 'when mandatory keys are missing' do
      it 'should raise a Exceptions::ArgumentError exception' do
        expect do
          described_class.build({})
        end.to raise_error Exceptions::ArgumentError, 'Missing Service parameters: id, name, description'
      end
    end

    context 'when optional keys are missing' do
      let(:service) do
        described_class.build(
        'id'          => 'service_id',
        'name'        => 'service_name',
        'description' => 'service_description',
      )
      end

      it 'sets the bindable field to true' do
        expect(service.bindable).to be_truthy
      end

      it 'sets the tags field to an empty array' do
        expect(service.tags).to eq([])
      end

      it 'sets the metadata field to nil' do
        expect(service.metadata).to be_nil
      end

      it 'sets the requires field to an empty array' do
        expect(service.requires).to eq([])
      end

      it 'sets the plans field to an empty array' do
         expect(service.plans).to eq([])
       end

      it 'sets the dashboard_client field to an empty hash' do
         expect(service.dashboard_client).to eq({})
       end
    end
  end

  describe '#to_hash' do
    it 'contains the correct values' do
      service_hash = service.to_hash

      expect(service_hash.fetch('id')).to eq('service_id')
      expect(service_hash.fetch('name')).to eq('service_name')
      expect(service_hash.fetch('description')).to eq('service_description')
      expect(service_hash.fetch('bindable')).to eq(false)
      expect(service_hash.fetch('tags')).to eq(['tag'])
      expect(service_hash.fetch('metadata')).to eq({ 'meta_key' => 'meta_value' })
      expect(service_hash.fetch('requires')).to eq(['syslog_drain'])
      expect(service_hash.fetch('plans')).to eq(['plan-hash'])
      expect(service_hash.fetch('dashboard_client')).to eq({
        'id'           => 'client-id',
        'secret'       => 'client-secret',
        'redirect_uri' => 'https://broker.10.0.0.1.xip.io/manage/auth/cloudfoundry/callback',
      })
    end
  end
end
