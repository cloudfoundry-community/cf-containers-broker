# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe CloudControllerHttpClient do
  let(:subject) { described_class.new(auth_header) }
  let(:auth_header) { 'auth_header' }
  let(:protocol) { 'http' }
  let(:cc_api_uri) { "#{protocol}://api.10.0.0.1.xip.io" }
  let(:skip_ssl_validation) { true }
  let(:net_http) { double('Net::HTTP') }
  let(:net_http_get) { double('Net::HTTP::Get') }
  let(:response) { double('Response', body: '{}') }

  before do
    expect(Net::HTTP).to receive(:new).and_return(net_http)
    expect(Net::HTTP::Get).to receive(:new).and_return(net_http_get)
    expect(Settings).to receive(:cc_api_uri).and_return(cc_api_uri)
    expect(Settings).to receive(:skip_ssl_validation).and_return(skip_ssl_validation)
  end

  describe '#get' do
    it 'returns the parsed response body' do
      expect(net_http).to receive(:use_ssl=).with(false)
      expect(net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(net_http_get).to receive(:[]=).with('Authorization', auth_header)
      expect(net_http).to receive(:request).with(net_http_get).and_return(response)

      expect(subject.get('/path/to/endpoint')).to eq(JSON.parse(response.body))
    end

    context 'when the CC uri uses https' do
      let(:protocol) { 'https' }

      before do
        expect(net_http_get).to receive(:[]=)
        expect(net_http).to receive(:request).and_return(response)
      end

      it 'sets use_ssl to true' do
        expect(net_http).to receive(:use_ssl=).with(true)
        expect(net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

        subject.get('/path/to/endpoint')
      end

      context 'when skip_ssl_validation is false' do
        let(:skip_ssl_validation) { false }

        it 'verifies the ssl cert' do
          expect(net_http).to receive(:use_ssl=).with(true)
          expect(net_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

          subject.get('/path/to/endpoint')
        end
      end
    end
  end
end
