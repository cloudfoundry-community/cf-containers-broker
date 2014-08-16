# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class CloudControllerHttpClient
  attr_reader :auth_header

  def initialize(auth_header = nil)
    @auth_header = auth_header
  end

  def get(path)
    uri  = cc_uri(path)
    http = build_http(uri)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = auth_header

    response = http.request(request)

    JSON.parse(response.body)
  end

  private

  def cc_uri(path)
    URI.parse("#{Settings.cc_api_uri.gsub(/\/$/, '')}/#{path.gsub(/^\//, '')}")
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = Settings.skip_ssl_validation ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER

    http
  end
end
