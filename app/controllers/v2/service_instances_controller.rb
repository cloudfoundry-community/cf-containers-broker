# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class V2::ServiceInstancesController < V2::BaseController
  def update
    instance_guid = params.fetch(:id)
    service_guid = params.fetch(:service_id)
    plan_guid = params.fetch(:plan_id)
    organization_guid = params.fetch(:organization_guid)
    space_guid = params.fetch(:space_guid)

    unless plan = Catalog.find_plan_by_guid(plan_guid)
      return render status: 404, json: {
          'description' => "Cannot create a service instance. Plan #{plan_guid} was not found in the catalog"
      }
    end

    begin
      if plan.container_manager.can_allocate?(Settings.max_containers, plan.max_containers)
        if plan.container_manager.find(instance_guid)
          render status: 409, json: { 'description' => 'Service instance already exists' }
        else
          plan.container_manager.create(instance_guid)
          render status: 201, json: { dashboard_url: build_dashboard_url(service_guid,
                                                                         plan_guid,
                                                                         instance_guid) }
        end
      else
        render status: 507, json: { 'description' => 'Service capacity has been reached' }
      end
    rescue Exception => e
      Rails.logger.info(e.inspect)
      Rails.logger.info(e.backtrace.join("\n"))
      render status: 500, json: { 'description' => e.inspect }
    end

  end

  def destroy
    instance_guid = params.fetch(:id)
    service_guid = params.fetch(:service_id)
    plan_guid = params.fetch(:plan_id)

    unless plan = Catalog.find_plan_by_guid(plan_guid)
      return render status: 404, json: {
          'description' => "Cannot delete a service instance. Plan #{plan_guid} was not found in the catalog"
      }
    end

    begin
      if plan.container_manager.find(instance_guid)
        plan.container_manager.destroy(instance_guid)
        render status: 200, json: {}
      else
        render status: 410, json: {}
      end
    rescue Exception => e
      Rails.logger.info(e.inspect)
      Rails.logger.info(e.backtrace.join("\n"))
      render status: 500, json: { 'description' => e.message }
    end
  end

  private

  def build_dashboard_url(service_guid, plan_guid, instance_guid)
    domain = Settings.external_host
    path   = manage_instance_path(service_guid, plan_guid, instance_guid)

    "#{scheme}://#{domain}#{path}"
  end

  def scheme
    Settings.ssl_enabled == false ? 'http' : 'https'
  end
end
