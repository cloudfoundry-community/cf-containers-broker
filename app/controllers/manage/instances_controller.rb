# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
module Manage
  class InstancesController < ApplicationController
    before_filter :redirect_ssl
    before_filter :require_login
    before_filter :build_uaa_session
    before_filter :ensure_all_necessary_scopes_are_approved
    before_filter :ensure_can_manage_instance

    def show
      service_guid = params.fetch(:service_guid)
      plan_guid = params.fetch(:plan_guid)
      @instance_guid = params.fetch(:instance_guid)

      unless service = Catalog.find_service_by_guid(service_guid)
        return render status: 404, json: {
            'description' => "Cannot create a service instance. Service #{service_guid} was not found in the catalog"
        }
      end

      unless plan = Catalog.find_plan_by_guid(plan_guid)
        return render status: 404, json: {
            'description' => "Cannot create a service instance. Plan #{plan_guid} was not found in the catalog"
        }
      end

      unless container = plan.container_manager.find(@instance_guid)
        return render status: 404, json: {
            'description' => "Cannot create a service instance. Instance #{@instance_guid} was not found"
        }
      end

      @dashboard_name = "\"#{service.metadata.fetch('displayName', 'Containers')}\" Management Dashboard"
      image = service.metadata.fetch('imageUrl', '')
      @dashboard_image = image unless image.empty?
      @service_name = "#{service.name} (#{service.description})"
      @plan_name = "#{plan.name} (#{plan.description})"
      @instance_provider = "#{plan.container_manager.backend.capitalize}"
      @instance_details = plan.container_manager.details(@instance_guid)
      @instance_processes = plan.container_manager.processes(@instance_guid)
      @instance_stdout = plan.container_manager.stdout(@instance_guid)
      @instance_stderr = plan.container_manager.stderr(@instance_guid)
    end

    private

    def redirect_ssl
      redirect_to :protocol => 'https://' if Settings.ssl_enabled && request.protocol == 'http://'
      true
    end

    def require_login
      session[:service_guid] = params[:service_guid]
      session[:plan_guid] = params[:plan_guid]
      session[:instance_guid] = params[:instance_guid]
      unless logged_in?
        redirect_to '/manage/auth/cloudfoundry'
        return false
      end
    end

    def build_uaa_session
      @uaa_session = UaaSession.build(session[:uaa_access_token], session[:uaa_refresh_token], params.fetch(:service_guid))
      session[:uaa_access_token] = @uaa_session.access_token
    end

    def ensure_all_necessary_scopes_are_approved
      token_hash = CF::UAA::TokenCoder.decode(@uaa_session.access_token, verify: false)
      return true if has_necessary_scopes?(token_hash)

      if need_to_retry?
        session[:has_retried] = 'true'
        redirect_to '/manage/auth/cloudfoundry'
        return false
      else
        session[:has_retried] = 'false'
        render 'errors/approvals_error'
        return false
      end
    end

    def ensure_can_manage_instance
      cc_client = CloudControllerHttpClient.new(@uaa_session.auth_header)
      response_body = cc_client.get("/v2/service_instances/#{params[:instance_guid]}/permissions")
      unless !response_body.nil? && response_body['manage']
        render 'errors/not_authorized'
        return false
      end
    end

    def logged_in?
      oldest_allowable_last_seen_time = Time.now - Settings.session_expiry

      if session[:uaa_user_id].present? &&
          session[:uaa_access_token] &&
          (session[:last_seen] > oldest_allowable_last_seen_time)
        session[:last_seen] = Time.now
        return true
      end

      false
    end

    def has_necessary_scopes?(token_hash)
      %w(openid cloud_controller_service_permissions.read).all? { |scope| token_hash['scope'].include?(scope) }
    end

    def need_to_retry?
      session[:has_retried].nil? || session[:has_retried] == 'false'
    end
  end
end
