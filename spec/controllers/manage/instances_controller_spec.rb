# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Manage::InstancesController do
  let(:service_guid) { 'service-guid' }
  let(:plan_guid) { 'plan-guid' }
  let(:instance_guid) { 'instance-guid' }
  let(:ssl_enabled) { false }
  let(:session_expiry) { 5 }
  let(:uaa_session) { double('UaaSession', access_token: 'access-token', auth_header: 'auth-header') }
  let(:token_hash) { { 'scope' => %w(openid cloud_controller_service_permissions.read) } }
  let(:cc_client) { double('CloudControllerHttpClient') }
  let(:service) { double('Service', name: 'service', description: 'service', metadata: {}) }
  let(:plan) { double('Plan', name: 'plan', description: 'plan') }
  let(:container_manager) { double('ContainerManager', backend: 'docker') }
  let(:container) { double('Container') }

  describe '#show' do
    render_views

    let(:make_request) do
      get :show, { service_guid: service_guid, plan_guid: plan_guid, instance_guid: instance_guid }
    end

    before do
      allow(Settings).to receive(:ssl_enabled).and_return(ssl_enabled)
      allow(Settings).to receive(:session_expiry).and_return(session_expiry)
    end

    describe 'when ssl is enabled' do
      let(:ssl_enabled) { true }

      context 'and protocol is http' do
        it 'redirects to https' do
          @request.env['HTTPS'] = nil
          make_request

          expect(response.status).to eql(302)
          expect(response).to redirect_to(:protocol => 'https://')
        end
      end
    end

    describe 'when the user is not logged in' do
      context 'and there is no uaa session' do
        it 'redirects to auth' do
          make_request

          expect(response.status).to eql(302)
          expect(response).to redirect_to('/manage/auth/cloudfoundry')
        end
      end

      context 'and there is a uaa session' do
        before do
          session[:uaa_user_id]      = 'uaa-user-id'
          session[:uaa_access_token] = 'uaa-access-token'
        end

        context 'but the last_seen has expired' do
          before do
            session[:last_seen] = Time.now - (session_expiry + 1)
          end

          it 'redirects to auth' do
            make_request

            expect(response.status).to eql(302)
            expect(response).to redirect_to('/manage/auth/cloudfoundry')
          end
        end
      end
    end

    describe 'when the user does not have the necessary scopes' do
      let(:token_hash) { { 'scope' => %w(scope) } }

      before do
        session[:uaa_user_id] = 'uaa-user-id'
        session[:uaa_access_token] = 'uaa-access-token'
        session[:uaa_refresh_token] = 'uaa-refresh-token'
        session[:last_seen] = Time.now
        expect(UaaSession).to receive(:build).with('uaa-access-token', 'uaa-refresh-token', service_guid).and_return(uaa_session)
        expect(CF::UAA::TokenCoder).to receive(:decode).with('access-token', verify: false).and_return(token_hash)
        allow(Configuration).to receive(:manage_user_profile_url).and_return('login.com/profile')
      end

      it 'redirects to auth' do
        make_request

        expect(response.status).to eql(302)
        expect(response).to redirect_to('/manage/auth/cloudfoundry')
        expect(session[:has_retried]).to eq('true')
      end

      context 'and it is a retry'  do
        before do
          session[:has_retried] = 'true'
        end

        it 'renders the approvals_error template' do
          make_request

          expect(response.status).to eq(200)
          expect(response).to render_template('errors/approvals_error')
          expect(session[:has_retried]).to eq('false')
        end
      end
    end

    context 'when the user does not have permission to manage the instance' do
      before do
        session[:uaa_user_id] = 'uaa-user-id'
        session[:uaa_access_token] = 'uaa-access-token'
        session[:uaa_refresh_token] = 'uaa-refresh-token'
        session[:last_seen] = Time.now
        expect(UaaSession).to receive(:build).with('uaa-access-token', 'uaa-refresh-token', service_guid).and_return(uaa_session)
        expect(CF::UAA::TokenCoder).to receive(:decode).with('access-token', verify: false).and_return(token_hash)
        expect(CloudControllerHttpClient).to receive(:new).with('auth-header').and_return(cc_client)
        expect(cc_client).to receive(:get).with("/v2/service_instances/#{instance_guid}/permissions").and_return(nil)
      end

      it 'renders the not_authorized template' do
        make_request

        expect(response.status).to eql(200)
        expect(response).to render_template('errors/not_authorized')
      end
    end

    describe 'when the user is  logged in, has the necessary scopes and permission to manage the instance' do
      before do
        session[:uaa_user_id] = 'uaa-user-id'
        session[:uaa_access_token] = 'uaa-access-token'
        session[:uaa_refresh_token] = 'uaa-refresh-token'
        session[:last_seen] = Time.now
        expect(UaaSession).to receive(:build).with('uaa-access-token', 'uaa-refresh-token', service_guid).and_return(uaa_session)
        expect(CF::UAA::TokenCoder).to receive(:decode).with('access-token', verify: false).and_return(token_hash)
        expect(CloudControllerHttpClient).to receive(:new).with('auth-header').and_return(cc_client)
        expect(cc_client).to receive(:get).with("/v2/service_instances/#{instance_guid}/permissions").and_return('manage')
      end

      it 'returns a 200' do
        expect(Catalog).to receive(:find_service_by_guid).with(service_guid).and_return(service)
        expect(Catalog).to receive(:find_plan_by_guid).with(plan_guid).and_return(plan)
        expect(plan).to receive(:container_manager).exactly(6).and_return(container_manager)
        expect(container_manager).to receive(:find).with(instance_guid).and_return(container)
        expect(container_manager).to receive(:details).with(instance_guid)
        expect(container_manager).to receive(:processes).with(instance_guid)
        expect(container_manager).to receive(:stdout).with(instance_guid)
        expect(container_manager).to receive(:stderr).with(instance_guid)

        make_request

        expect(response.status).to eql(200)
      end

      context 'and the service does not exist' do
        before do
          expect(Catalog).to receive(:find_service_by_guid).with(service_guid).and_return(nil)
        end

        it 'returns a 404' do
          make_request

          expect(response.status).to eql(404)
          expect(JSON.parse(response.body)).to eq({
            'description' => "Cannot create a service instance. Service #{service_guid} was not found in the catalog"
          })
        end
      end

      context 'and the service plan does not exist' do
        before do
          expect(Catalog).to receive(:find_service_by_guid).with(service_guid).and_return(service)
          expect(Catalog).to receive(:find_plan_by_guid).with(plan_guid).and_return(nil)
        end

        it 'returns a 404' do
          make_request

          expect(response.status).to eql(404)
          expect(JSON.parse(response.body)).to eq({
            'description' => "Cannot create a service instance. Plan #{plan_guid} was not found in the catalog"
          })
        end
      end

      context 'and the service instance does not exist' do
        before do
          expect(Catalog).to receive(:find_service_by_guid).with(service_guid).and_return(service)
          expect(Catalog).to receive(:find_plan_by_guid).with(plan_guid).and_return(plan)
          expect(plan).to receive(:container_manager).and_return(container_manager)
          expect(container_manager).to receive(:find).with(instance_guid).and_return(nil)
        end

        it 'returns a 404' do
          make_request

          expect(response.status).to eql(404)
          expect(JSON.parse(response.body)).to eq({
            'description' => "Cannot create a service instance. Instance #{instance_guid} was not found"
          })
        end
      end
    end
  end
end
