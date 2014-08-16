# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class V2::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_filter :authenticate
  before_filter :log_request_headers_and_body
  after_filter :log_response_headers_and_body

  protected

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == Settings.auth_username && password == Settings.auth_password
    end
  end

  private

  def log_request_headers_and_body
    RequestResponseLogger.new('Request:', logger).log_headers_and_body(request.env,
                                                                       request.body.read)
  end

  def log_response_headers_and_body
    RequestResponseLogger.new('Response:', logger).log_headers_and_body(response.headers,
                                                                        response.body,
                                                                        true)
  end
end
