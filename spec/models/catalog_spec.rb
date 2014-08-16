# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Catalog do
  let(:subject) { described_class }

  let(:services) {
    [
      service_1,
      service_2,
    ]
  }
  let(:service_1) {
    double(
      'Service',
      id: 'service_id_1',
      name: 'service_name_1',
      description: 'service_description_1',
      plans: service_1_plans,
    )
  }
  let(:service_1_plans) { [plan_1, plan_2] }
  let(:service_2) {
    double(
      'Service',
      id: 'service_id_2',
      name: 'service_name_2',
      description: 'service_description_2',
      plans: service_2_plans,
    )
  }
  let(:service_2_plans) { [plan_3] }
  let(:plan_1) {
    double(
      'Plan',
      id: 'plan_id_1',
      name: 'plan_name_1',
      description: 'plan_description_1',
    )
  }
  let(:plan_2) {
    double(
      'Plan',
      id: 'plan_id_2',
      name: 'plan_name_2',
      description: 'plan_description_2',
    )
  }
  let(:plan_3) {
    double(
      'Plan',
      id: 'plan_id_3',
      name: 'plan_name_3',
      description: 'plan_description_3',
    )
  }

  before do
    expect(Settings).to receive(:[]).with('services').and_return(services)
    allow(Service).to receive(:build).and_return(service_1, service_2)
  end

  describe '#find_service_by_guid' do
    context 'when service guid exists' do
      it 'returns the service' do
        expect(subject.find_service_by_guid('service_id_1')).to eq(service_1)
      end
    end

    context 'when service guid does not exists' do
      it 'returns nil' do
         expect(subject.find_service_by_guid('unknow')).to be_nil
      end
    end
  end

  describe '#services' do
    it 'returns an array of service objects representing the services in the catalog' do
      expect(subject.services).to eq([service_1, service_2])
    end

    context 'when there are no services' do
      let(:services) { nil }

      it 'returns an empty array' do
        expect(subject.services).to eq([])
      end
    end
  end

  describe '#find_plan_by_guid' do
    context 'when plan guid exists' do
      it 'returns the plan' do
        expect(subject.find_plan_by_guid('plan_id_1')).to eq(plan_1)
      end
    end

    context 'when plan guid does not exists' do
      it 'returns nil' do
         expect(subject.find_plan_by_guid('unknow')).to be_nil
      end
    end
  end

  describe '#plans' do
    it 'returns an array of plan objects representing the plans in the catalog' do
      expect(subject.plans).to eq([plan_1, plan_2, plan_3])
    end

    context 'when there are no plans' do
      let(:service_1_plans) { [] }
      let(:service_2_plans) { [] }

      it 'returns an empty array' do
        expect(subject.plans).to eq([])
      end
    end
  end
end
