# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('lib/settings')
require Rails.root.join('app/models/service')

class Catalog
  class << self
    def find_service_by_guid(service_guid)
      services.find { |service| service.id == service_guid }
    end

    def services
      (Settings['services'] || []).map { |attrs| Service.build(attrs) }
    end

    def find_plan_by_guid(plan_guid)
      plans.find { |plan| plan.id == plan_guid }
    end

    def plans
      services.map { |service| service.plans }.flatten
    end
  end
end
