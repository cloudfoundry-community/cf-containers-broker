# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('app/models/plan')

class Service
  attr_reader :id, :name, :description, :bindable, :tags, :metadata, :requires, :plans, :dashboard_client

  def self.build(attrs)
    plan_attrs = attrs['plans'] || []
    plans      = plan_attrs.map { |attr| Plan.build(attr) }
    new(attrs.merge('plans' => plans))
  end

  def initialize(attrs)
    validate_attrs(attrs)

    @id          = attrs.fetch('id')
    @name        = attrs.fetch('name')
    @description = attrs.fetch('description')
    @bindable    = attrs.fetch('bindable', true)
    @tags        = attrs.fetch('tags', []) || []
    @metadata    = attrs.fetch('metadata', nil)
    @requires    = attrs.fetch('requires', []) || []
    @plans       = attrs.fetch('plans')
    @dashboard_client = attrs.fetch('dashboard_client', {}) || {}
  end

  def to_hash
    {
      'id'               => id,
      'name'             => name,
      'description'      => description,
      'bindable'         => bindable,
      'tags'             => tags,
      'metadata'         => metadata,
      'requires'         => requires,
      'plans'            => plans.map(&:to_hash),
      'dashboard_client' => dashboard_client,
    }
  end

  private

  def validate_attrs(attrs)
    required_keys = %w(id name description plans)
    missing_keys = []

    required_keys.each do |key|
      missing_keys << "#{key}" unless attrs.key?(key)
    end

    unless missing_keys.empty?
      raise Exceptions::ArgumentError, "Missing Service parameters: #{missing_keys.join(', ')}"
    end
  end
end
