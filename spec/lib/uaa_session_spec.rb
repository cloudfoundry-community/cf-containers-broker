# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe UaaSession do
  let(:subject) { described_class }

  describe '#build' do
    let(:handler) { subject.build(access_token, refresh_token, service_guid) }
    let(:access_token) { 'my_access_token' }
    let(:refresh_token) { 'my_refresh_token' }
    let(:service_guid) { 'service-guid' }
    let(:token_info) {
      double('token_info', auth_header: "token #{auth_header}", info: { access_token: access_token })
    }
    let(:auth_header) { 'auth_header' }
    let(:auth_server_url) { 'https://login.10.0.0.1.xip.io' }
    let(:token_server_url) { 'https://uaa.10.0.0.1.xip.io' }
    let(:service) {
      double('Service', dashboard_client: { 'id' => dashboard_client_id, 'secret' => dashboard_client_secret })
    }
    let(:dashboard_client_id) { 'client id' }
    let(:dashboard_client_secret) { 'client secret' }
    let(:token_issuer) { double(CF::UAA::TokenIssuer) }

    before do
      allow(CF::UAA::TokenInfo).to receive(:new)
                                   .with(access_token: access_token, token_type: 'bearer')
                                   .and_return(token_info)
    end

    context 'when the access token is not expired' do
      before do
        expect(CF::UAA::TokenCoder).to receive(:decode)
                                       .with(auth_header, verify: false)
                                       .and_return('exp' => 1.minute.from_now.to_i)
      end

      it 'returns a token that is encoded and can be used in a header' do
        expect(handler.auth_header).to eql("token #{auth_header}")
      end

      it 'sets access token to the given token' do
        expect(handler.access_token).to eq(access_token)
      end
    end

    context 'when the access token is expired' do
      before do
        expect(CF::UAA::TokenCoder).to receive(:decode)
                                       .with(auth_header, verify: false)
                                       .and_return('exp' => 1.minute.ago.to_i)
        expect(Catalog).to receive(:find_service_by_guid)
                           .with(service_guid)
                           .and_return(service)
        expect(Configuration).to receive(:auth_server_url).and_return(auth_server_url)
        expect(Configuration).to receive(:token_server_url).and_return(token_server_url)
        expect(CF::UAA::TokenIssuer).to receive(:new)
                                        .with(auth_server_url,
                                              dashboard_client_id,
                                              dashboard_client_secret,
                                              { token_target: token_server_url })
                                        .and_return(token_issuer)
        expect(token_issuer).to receive(:refresh_token_grant)
                                .with(refresh_token)
                                .and_return(token_info)
      end

      it 'uses the refresh token to get a new access token' do
        expect(handler.auth_header).to eql("token #{auth_header}")
      end

      it 'updates the tokens' do
        expect(handler.access_token).to eql(access_token)
      end
    end
  end
end
