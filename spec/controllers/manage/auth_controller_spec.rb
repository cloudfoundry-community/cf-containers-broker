# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Manage::AuthController do
  let(:service_guid) { 'service-guid' }
  let(:plan_guid) { 'plan-guid' }
  let(:instance_guid) { 'instance-guid' }

  describe '#create' do
    let(:auth) {
      {
        'extra' => extra,
        'credentials' => credentials,
      }
    }
    let(:credentials) {
      {
        'token' => 'access-token',
        'refresh_token' => 'refresh-token',
      }
    }
    let(:extra) {
      {
        'raw_info' => {
          'user_id' => 'user-id'
        }
      }
    }

    before do
      session[:service_guid] = service_guid
      session[:plan_guid] = plan_guid
      session[:instance_guid] = instance_guid
      request.env['omniauth.auth'] = auth
    end

    context 'when access token, refresh token, and user info are present' do
      it 'authenticates the user based on the permissions from UAA' do
        get :create
        expect(response.status).to eql(302)
        expect(response).to redirect_to(manage_instance_path(service_guid, plan_guid, instance_guid))

        expect(session[:uaa_user_id]).to eql('user-id')
        expect(session[:uaa_access_token]).to eql('access-token')
        expect(session[:uaa_refresh_token]).to eql('refresh-token')
        expect(session[:last_seen]).to be_a_kind_of(Time)
      end
    end

    context 'when omniauth does not yield an access token' do
      let(:credentials) { {} }

      it 'renders the approvals error page' do
        get :create

        expect(response.status).to eql(200)
        expect(response).to render_template 'errors/approvals_error'
      end
    end

    context 'when omniauth does not yield user info (raw_info)' do
      let(:extra) { {} }

      it 'renders the approvals error page' do
        get :create

        expect(response.status).to eql(200)
        expect(response).to render_template 'errors/approvals_error'
      end
    end
  end

  describe '#failure' do
    it 'returns a 403 status code' do
      get :failure, message: 'Not allowed'
      expect(response.status).to eql(403)
      expect(response.body).to eql('Not allowed')
    end
  end
end
