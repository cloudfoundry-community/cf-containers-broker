# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
def log_message_matching_type(message_type, log_message)
  match_data = /^\s+#{message_type}\s+(.*)/.match(log_message)
  if match_data
    json_info = match_data[1]

    parsed_data = JSON.parse(json_info)
    parsed_data if parsed_data.has_key?('headers') && parsed_data.has_key?('body')
  end
end

def get_logged_message(message_type)
  received_log_messages = []
  allow(Rails.logger).to receive(:info) do |log_message|
    matching_message = log_message_matching_type(message_type, log_message)
    received_log_messages << matching_message unless matching_message.nil?
  end

  make_request

  expect(received_log_messages.length).to eq 1
  received_log_messages.first
end

shared_examples_for 'a controller action that logs its request and response headers and body' do
  it 'logs the request' do
    message = get_logged_message("Request:")
    expect(message).to have_key('body')
    expect(message['headers']).not_to be_empty
  end

  it 'logs the response' do
    message = get_logged_message("Response:")
    expect(message['body']).not_to be_empty
    expect(message['headers']).not_to be_empty
  end
end

shared_examples_for 'a controller action that requires basic auth' do
  context 'when the basic-auth username is incorrect' do
    before do
      set_basic_auth('wrong_username', Settings.auth_password)
    end

    it 'responds with a 401' do
      make_request

      expect(response.status).to eq(401)
    end
  end
end

module ControllerHelpers
  extend ActiveSupport::Concern

  def authenticate
    set_basic_auth(Settings.auth_username, Settings.auth_password)
  end

  def set_basic_auth(username, password)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end
