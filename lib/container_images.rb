# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('app/models/catalog')

module ContainerImages
  extend self

  def fetch
    Rails.logger.info('Looking for container images at the Services Catalog')
    Catalog.plans.each do |plan|
      plan.container_manager.fetch_image
    end
  end
end
