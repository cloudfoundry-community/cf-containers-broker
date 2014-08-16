# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe RequestResponseLogger do
  let(:subject) { described_class.new('Message:', rails_logger) }
  let(:rails_logger) { double('Rails.logger') }
  let(:headers) {
    {
      'CONTENT_TYPE' => 'application/json',
      'HTTP_AUTHORIZATION' => 'basic: auth-token',
      'THIS_KEY_SHOULD_NOT_BE_LOGGED' => 'unknown'
    }
  }

  describe '#log_headers_and_body' do
    it 'logs the request headers and body' do
      expect(rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, '')

        request_info = JSON.parse(json_log_message)
        expect(request_info['body']).to eq 'body'
        expect(request_info['headers']['CONTENT_TYPE']).to eq 'application/json'
      end

      subject.log_headers_and_body(headers, 'body')
    end

    it 'filters out sensitive data headers' do
      expect(rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, '')

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']['HTTP_AUTHORIZATION']).not_to match 'some-auth-token'
      end

      subject.log_headers_and_body(headers, 'body')
    end

    it 'does not log unknown headers' do
      expect(rails_logger).to receive(:info) do |log_message|
        json_log_message = log_message.sub(/^\s+Message:\s+/, '')

        request_info = JSON.parse(json_log_message)
        expect(request_info['headers']).not_to have_key('THIS_KEY_SHOULD_NOT_BE_LOGGED')
      end

      subject.log_headers_and_body(headers, 'body')
    end

    context 'when log_all_headers is true' do
      it 'filters out sensitive data headers' do
        expect(rails_logger).to receive(:info) do |log_message|
          json_log_message = log_message.sub(/^\s+Message:\s+/, '')

          request_info = JSON.parse(json_log_message)
          expect(request_info['headers']['HTTP_AUTHORIZATION']).not_to match 'some-auth-token'
        end

        subject.log_headers_and_body(headers, 'body', true)
      end

      it 'logs unknown headers' do
        expect(rails_logger).to receive(:info) do |log_message|
          json_log_message = log_message.sub(/^\s+Message:\s+/, '')

          request_info = JSON.parse(json_log_message)
          expect(request_info['headers']).to have_key('THIS_KEY_SHOULD_NOT_BE_LOGGED')
        end

        subject.log_headers_and_body(headers, 'body', true)
      end
    end
  end
end
