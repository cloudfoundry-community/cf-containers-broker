# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class V2::ServiceBindingsController < V2::BaseController
  def update
    binding_guid = params.fetch(:id)
    instance_guid = params.fetch(:service_instance_id)
    service_guid = params.fetch(:service_id)
    plan_guid = params.fetch(:plan_id)
    app_guid = params.fetch(:app_guid)

    unless plan = Catalog.find_plan_by_guid(plan_guid)
      return render status: 404, json: {
          'description' => "Cannot bind a service. Plan #{plan_guid} was not found in the catalog"
      }
    end

    begin
      if plan.container_manager.find(instance_guid)
        response = { 'credentials' => plan.container_manager.service_credentials(instance_guid) }
        if syslog_drain_url = plan.container_manager.syslog_drain_url(instance_guid)
          response['syslog_drain_url'] = syslog_drain_url
        end
        render status: 201, json: response
      else
        render status: 404, json: {
            'description' => "Cannot bind a service. Service Instance #{instance_guid} was not found"
        }
      end
    rescue Exception => e
      Rails.logger.info(e.inspect)
      Rails.logger.info(e.backtrace.join("\n"))
      render status: 500, json: { 'description' => e.message }
    end
  end

  def destroy
    binding_guid = params.fetch(:id)
    instance_guid = params.fetch(:service_instance_id)
    service_guid = params.fetch(:service_id)
    plan_guid = params.fetch(:plan_id)

    render status: 200, json: {}
  end
end
