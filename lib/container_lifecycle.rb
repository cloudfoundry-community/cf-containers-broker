# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('app/models/catalog')

module ContainerLifecycle
  extend self

  def update_all
    Rails.logger.info('Updating all tagged containers')
    Catalog.plans.each do |plan|
      plan.container_manager.update_all_containers
    end
  end
end
