# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class UaaSession
  class << self
    def build(access_token, refresh_token, service_guid)
      token_info = existing_token_info(access_token)
      if token_expired?(token_info)
        token_info = refreshed_token_info(refresh_token, service_guid)
      end

      new(token_info)
    end

    private

    def existing_token_info(access_token)
      CF::UAA::TokenInfo.new(access_token: access_token, token_type: 'bearer')
    end

    def token_expired?(token_info)
      header = token_info.auth_header
      expiry = CF::UAA::TokenCoder.decode(header.split[1], verify: false)['exp']
      expiry.is_a?(Integer) && expiry <= Time.now.to_i
    end

    def refreshed_token_info(refresh_token, service_guid)
      service = Catalog.find_service_by_guid(service_guid)
      client = CF::UAA::TokenIssuer.new(
        Configuration.auth_server_url,
        service.dashboard_client['id'],
        service.dashboard_client['secret'],
        token_target: Configuration.token_server_url,
      )
      client.refresh_token_grant(refresh_token)
    end
  end

  def initialize(token_info)
    @token_info = token_info
  end

  def auth_header
    token_info.auth_header
  end

  def access_token
    token_info.info[:access_token]
  end

  private

  attr_reader :token_info
end
