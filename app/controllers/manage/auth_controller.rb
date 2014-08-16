# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
module Manage
  class AuthController < ApplicationController
    def create
      auth        = request.env['omniauth.auth'].to_hash
      credentials = auth['credentials']

      token = credentials['token']
      return render 'errors/approvals_error' if token.nil? || token.empty?

      raw_info = auth['extra']['raw_info']
      return render 'errors/approvals_error' unless raw_info

      session[:uaa_user_id]       = auth['extra']['raw_info']['user_id']
      session[:uaa_access_token]  = credentials['token']
      session[:uaa_refresh_token] = credentials['refresh_token']
      session[:last_seen]         = Time.now

      redirect_to manage_instance_path(session[:service_guid],
                                       session[:plan_guid],
                                       session[:instance_guid])
    end

    def failure
      render text: params[:message], status: 403
    end
  end
end
