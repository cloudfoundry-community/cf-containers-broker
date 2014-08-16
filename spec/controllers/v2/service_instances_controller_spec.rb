# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe V2::ServiceInstancesController do
  let(:service_id) { 'service-id' }
  let(:plan_id) { 'plan-id' }
  let(:instance_id) { 'instance-id' }
  let(:organization_guid) { 'organization-guid' }
  let(:space_guid) { 'space_guid' }
  let(:plan) { double('Plan', max_containers: max_plan_containers) }
  let(:container_manager) { double('ContainerManager') }
  let(:container) { double('Container') }
  let(:can_allocate) { true }
  let(:max_containers) { 1 }
  let(:max_plan_containers) { 1 }
  let(:external_host) { 'my-host' }
  let(:ssl_enabled) { false }

  before do
    authenticate
    allow(Docker).to receive(:version).and_return({ 'ApiVersion' => DockerManager::MIN_SUPPORTED_DOCKER_API_VERSION })
  end

  describe '#update' do
    let(:make_request) do
      put :update, { id: instance_id, service_id: service_id, plan_id: plan_id, organization_guid: organization_guid, space_guid: space_guid }
    end

    before do
      allow(Settings).to receive(:max_containers).and_return(max_containers)
      allow(Settings).to receive(:ssl_enabled).and_return(ssl_enabled)
    end

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'when the service instance is created' do
      before do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).exactly(3).and_return(container_manager)
        expect(container_manager).to receive(:can_allocate?)
                                     .with(max_containers, max_plan_containers)
                                     .and_return(can_allocate)
        expect(container_manager).to receive(:find).with(instance_id).and_return(nil)
        expect(container_manager).to receive(:create).with(instance_id)
        expect(Settings).to receive(:external_host).and_return(external_host)
      end

      it 'returns a 201' do
        make_request

        expect(response.status).to eq(201)
      end

      it 'returns a hash with a dashboard_url' do
        make_request

        expect(JSON.parse(response.body)).to eq({
          'dashboard_url' => "http://#{external_host}/manage/instances/#{service_id}/#{plan_id}/#{instance_id}"
        })
      end

      context 'and ssl is enabled' do
        let(:ssl_enabled) { true }

        it 'returns a hash with a dashboard_url using https' do
          make_request

          expect(JSON.parse(response.body)).to eq({
            'dashboard_url' => "https://#{external_host}/manage/instances/#{service_id}/#{plan_id}/#{instance_id}"
          })
        end
      end
    end

    context 'when service capacity has been reached' do
      let(:can_allocate) { false }

      it 'returns a 507' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).and_return(container_manager)
        expect(container_manager).to receive(:can_allocate?)
                                     .with(max_containers, max_plan_containers)
                                     .and_return(can_allocate)

        make_request

        expect(response.status).to eq(507)
        expect(JSON.parse(response.body)).to eq({ 'description' => 'Service capacity has been reached' })
      end
    end

    context 'when the service instance already exist' do
      it 'returns a 409' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).twice.and_return(container_manager)
        expect(container_manager).to receive(:can_allocate?)
                                     .with(max_containers, max_plan_containers)
                                     .and_return(can_allocate)
        expect(container_manager).to receive(:find).with(instance_id).and_return(container)

        make_request

        expect(response.status).to eq(409)
        expect(JSON.parse(response.body)).to eq({ 'description' => 'Service instance already exists' })
      end
    end

    context 'when the service plan does not exist' do
      it 'returns a 404' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(nil)

        make_request

        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)).to eq({
          'description' => "Cannot create a service instance. Plan #{plan_id} was not found in the catalog"
        })
      end
    end
  end

  describe '#destroy' do
    let(:make_request) { delete :destroy, id: instance_id, service_id: service_id, plan_id: plan_id }

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'when the service instance exists' do
      before do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).twice.and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_id).and_return(true)
      end

      it 'destroys the service instance and returns a 200' do
        expect(container_manager).to receive(:destroy).with(instance_id)

        make_request

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({})
      end

      context 'then the service instance cannot be deleted' do
        it 'returns a 500' do
          expect(container_manager).to receive(:destroy)
                                       .with(instance_id)
                                       .and_raise(Exceptions::NotFound, 'Container not found')
          make_request

          expect(response.status).to eq(500)
          expect(JSON.parse(response.body)).to eq({ 'description' => 'Container not found' })

        end
      end
    end

    context 'when the service instance does not exist' do
      it 'returns a 410' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(plan)
        expect(plan).to receive(:container_manager).and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_id).and_return(nil)
        make_request

        expect(response.status).to eq(410)
        expect(JSON.parse(response.body)).to eq({})
      end
    end

    context 'when the service plan does not exist' do
      it 'returns a 404' do
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_id).and_return(nil)

        make_request

        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)).to eq({
          'description' => "Cannot delete a service instance. Plan #{plan_id} was not found in the catalog"
        })
      end
    end
  end
end
