# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe V2::ServiceBindingsController do
  let(:service_id) { 'service-id' }
  let(:plan_id) { 'plan-id' }
  let(:instance_id) { 'instance-id' }
  let(:binding_id) { 'binding-id' }
  let(:app_guid) { 'app-guid' }
  let(:plan) { double('Plan') }
  let(:container_manager) { double('ContainerManager') }
  let(:container) { double('Container') }
  let(:credentials) { 'credentials-hash' }
  let(:syslog_drain_url) { nil }

  before do
    authenticate
    allow(Docker).to receive(:version).and_return({ 'ApiVersion' => DockerManager::MIN_SUPPORTED_DOCKER_API_VERSION })
  end

  describe '#update' do
    let(:make_request) do
      put :update, { id: binding_id, service_instance_id: instance_id, service_id: service_id, plan_id: plan_id,
                     app_guid: app_guid }
    end

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'when the service instance is bound' do
      before do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).exactly(3).times.and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_id).and_return(container)
        expect(container_manager).to receive(:service_credentials)
                                     .with(instance_id)
                                     .and_return(credentials)
        expect(container_manager).to receive(:syslog_drain_url)
                                     .with(instance_id)
                                     .and_return(syslog_drain_url)
      end

      it 'returns a 201' do
        make_request

        expect(response.status).to eq(201)
      end

      it 'returns a hash with credentials' do
        make_request

        expect(JSON.parse(response.body)).to eq({ 'credentials' => credentials })
      end

      context 'and has a syslog drain url' do
        let(:syslog_drain_url) { 'syslog-drain-url' }

        it 'returns a 201' do
          make_request

          expect(response.status).to eq(201)
        end

        it 'returns a hash with a syslog drain url' do
          make_request

          expect(JSON.parse(response.body)).to eq({
            'credentials' => credentials, 'syslog_drain_url' => syslog_drain_url
          })
        end
      end
    end

    context 'when the service plan does not exist' do
      it 'returns a 404' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(nil)

        make_request

        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)).to eq({
          'description' => "Cannot bind a service. Plan #{plan_id} was not found in the catalog"
        })
      end
    end

    context 'when the service instance does not exist' do
      it 'returns a 404' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_id).and_return(nil)
        make_request

        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)).to eq({
          'description' => "Cannot bind a service. Service Instance #{instance_id} was not found"
        })
      end
    end

    context 'then the service instance cannot be bound' do
      it 'returns a 500' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).twice.and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_id).and_return(container)
        expect(container_manager).to receive(:service_credentials)
                                     .with(instance_id)
                                     .and_raise(Exceptions::NotFound, 'Container not found')
        make_request

        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({ 'description' => 'Container not found' })
      end
    end
  end

  describe '#destroy' do
    let(:make_request) {
      delete :destroy, id: binding_id, service_instance_id: instance_id, service_id: service_id, plan_id: plan_id
    }

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    it 'returns a 200' do
      make_request

      expect(response.status).to eq(200)
      expect(response.body).to eq('{}')
    end
  end
end
