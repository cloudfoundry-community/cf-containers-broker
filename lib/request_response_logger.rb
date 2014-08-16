# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class RequestResponseLogger
  attr_reader :logger
  attr_reader :message_type

  def initialize(message_type, logger)
    @message_type = message_type
    @logger = logger
  end

  def log_headers_and_body(headers, body, log_all_headers = false)
    headers_to_log = log_all_headers ? headers : remove_non_permitted_headers(headers)

    request_summary = {
      headers: filtered_headers(headers_to_log),
      body:    body
    }

    logger.info "  #{message_type} #{request_summary.to_json}"
  end

  private

  def filtered_headers(headers)
    headers.keys.each do |k|
      headers[k] = '[PRIVATE DATA HIDDEN]' if filtered_keys.include?(k)
    end

    headers
  end

  def remove_non_permitted_headers(headers)
    headers.select { |key, _| permitted_keys.include? key }
  end

  def permitted_keys
    %w(CONTENT_LENGTH
       CONTENT_TYPE
       GATEWAY_INTERFACE
       PATH_INFO
       QUERY_STRING
       REMOTE_ADDR
       REMOTE_HOST
       REQUEST_METHOD
       REQUEST_URI
       SCRIPT_NAME
       SERVER_NAME
       SERVER_PORT
       SERVER_PROTOCOL
       SERVER_SOFTWARE
       HTTP_ACCEPT
       HTTP_USER_AGENT
       HTTP_AUTHORIZATION
       HTTP_X_VCAP_REQUEST_ID
       HTTP_X_BROKER_API_VERSION
       HTTP_HOST
       HTTP_VERSION
       REQUEST_PATH)
  end

  def filtered_keys
    %w(HTTP_AUTHORIZATION)
  end
end
