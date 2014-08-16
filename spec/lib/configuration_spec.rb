# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Configuration do
  let(:subject) { described_class }
  let(:cc_client) { double('CloudControllerHttpClient') }
  let(:authorization_endpoint) { 'https://login.10.0.0.1.xip.io' }
  let(:token_endpoint) { 'https://uaa.10.0.0.1.xip.io' }
  let(:cc_info) {
    {
      'name' => 'vcap',
      'build' => '2222',
      'support' => 'http://support.cloudfoundry.com',
      'version' => 2,
      'description' => 'Cloud Foundry sponsored by Pivotal',
      'authorization_endpoint' => authorization_endpoint,
      'token_endpoint' => token_endpoint,
      'api_version' => '2.8.0',
      'logging_endpoint' => 'wss://loggregator.10.0.0.1.xip.io',
    }
  }

  before do
    Configuration.clear
    allow(CloudControllerHttpClient).to receive(:new).and_return(cc_client)
  end

  describe '#documentation_url' do
    it 'uses the documentationUrl of the first service in the catalog' do
      expect(subject.documentation_url).to eql('http://docs.run.pivotal.io')
    end

    context 'when the catalog is empty' do
      it 'is nil' do
        expect(Settings).to receive(:services).and_return([])

        expect(subject.documentation_url).to be_nil
      end
    end
  end

  describe '#support_url' do
    it 'uses the supportUrl of the first service in the catalog' do
      expect(subject.support_url).to eql('http://support.run.pivotal.io/home')
    end

    context 'when the catalog is empty' do
      it 'is nil' do
        expect(Settings).to receive(:services).and_return([])

        expect(subject.support_url).to be_nil
      end
    end
  end

  describe '#manage_user_profile_url' do
    it 'uses the cc info endpoint to get the uri for the auth server' do
      expect(cc_client).to receive(:get).with('/info').and_return(cc_info)

      expect(subject.manage_user_profile_url).to eql("#{authorization_endpoint}/profile")
    end

  end

  describe '#auth_server_url' do
    it 'uses the cc info endpoint to get the uri for the auth server' do
      expect(cc_client).to receive(:get).with('/info').and_return(cc_info)

      expect(subject.auth_server_url).to eql(authorization_endpoint)
    end
  end

  describe '#token_server_url' do
    it 'uses the cc info endpoint to get the url for the token server' do
      expect(cc_client).to receive(:get).with('/info').and_return(cc_info)

      expect(subject.token_server_url).to eql(token_endpoint)
    end
  end
end
