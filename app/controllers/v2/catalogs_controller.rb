# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class V2::CatalogsController < V2::BaseController
  def show
    render status: 200, json: { services: Catalog.services.map { |service| service.to_hash } }
  end
end
