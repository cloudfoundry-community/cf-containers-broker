# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('app/models/container_manager')
require Rails.root.join('app/models/credentials')

class Plan
  attr_reader :id, :name, :description, :metadata, :free, :max_containers, :credentials,
              :syslog_drain_port, :syslog_drain_protocol, :container_manager

  def self.build(attrs)
    new(attrs)
  end

  def initialize(attrs)
    validate_attrs(attrs)

    @id                    = attrs.fetch('id')
    @name                  = attrs.fetch('name')
    @description           = attrs.fetch('description')
    @metadata              = attrs.fetch('metadata', nil)
    @free                  = attrs.fetch('free', true)
    @max_containers        = attrs.fetch('max_containers', nil)
    @credentials           = attrs.fetch('credentials', {})
    @syslog_drain_port     = attrs.fetch('syslog_drain_port', nil)
    @syslog_drain_protocol = attrs.fetch('syslog_drain_protocol', 'syslog')
    @container_manager = build_container_manager(attrs.fetch('container'))
  end

  def to_hash
    {
      'id'          => id,
      'name'        => name,
      'description' => description,
      'metadata'    => metadata,
      'free'        => free,
    }
  end

  private

  def validate_attrs(attrs)
    required_keys = %w(id name description container)
    missing_keys = []

    required_keys.each do |key|
      missing_keys << "#{key}" unless attrs.key?(key)
    end

    unless missing_keys.empty?
      raise Exceptions::ArgumentError, "Missing Plan parameters: #{missing_keys.join(', ')}"
    end
  end

  def build_container_manager(attrs)
    container_backend = attrs.fetch('backend')

    begin
      require Rails.root.join("app/models/#{container_backend}_manager")
    rescue LoadError => error
      raise Exceptions::NotSupported, "Could not load Container Manager for backend `#{container_backend}'"
    end

    container_attrs = attrs.merge('credentials' => credentials,
                                  'syslog_drain_port' => syslog_drain_port,
                                  'syslog_drain_protocol' => syslog_drain_protocol)
    Class.const_get("#{container_backend.capitalize}Manager").new(container_attrs)
  end
end
