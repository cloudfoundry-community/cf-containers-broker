# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class ContainerManager
  CONTAINER_PREFIX = 'cf'.freeze

  attr_reader :backend, :credentials, :syslog_drain_port, :syslog_drain_protocol

  def initialize(attrs)
    validate_attrs(attrs)
    @backend               = attrs.fetch('backend')
    @credentials           = Credentials.new(attrs.fetch('credentials', {}))
    @syslog_drain_port     = attrs.fetch('syslog_drain_port', nil)
    @syslog_drain_protocol = attrs.fetch('syslog_drain_protocol', 'syslog')
  end

  def find(guid)
    raise Exceptions::NotImplemented, "`find' is not implemented by `#{self.class}'"
  end

  def can_allocate?(max_containers, max_plan_containers)
    raise Exceptions::NotImplemented, "`can_allocate?' is not implemented by `#{self.class}'"
  end

  def create(guid)
    raise Exceptions::NotImplemented, "`create' is not implemented by `#{self.class}'"
  end

  def destroy(guid)
    raise Exceptions::NotImplemented, "`destroy' is not implemented by `#{self.class}'"
  end

  def fetch_image
    raise Exceptions::NotImplemented, "`fetch_image' is not implemented by `#{self.class}'"
  end

  def service_credentials(guid)
    raise Exceptions::NotImplemented, "`service_credentials' is not implemented by `#{self.class}'"
  end

  def syslog_drain_url(guid)
    nil
  end

  def details(guid)
    nil
  end

  def processes(guid)
    nil
  end

  def stdout(guid)
    nil
  end

  def stderr(guid)
    nil
  end

  private

  def container_name(guid)
    "#{CONTAINER_PREFIX}-#{guid}"
  end

  def validate_attrs(attrs)
    required_keys = %w(backend)
    missing_keys = []

    required_keys.each do |key|
      missing_keys << "#{key}" unless attrs.key?(key)
    end

    unless missing_keys.empty?
      raise Exceptions::ArgumentError, "Missing Container parameters: #{missing_keys.join(', ')}"
    end
  end
end
