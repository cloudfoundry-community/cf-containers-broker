# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
class Credentials
  USERNAME_PREFIX = 'USER'.freeze
  PASSWORD_PREFIX = 'PWD'.freeze
  DBNAME_PREFIX =   'DB'.freeze

  attr_reader :credentials

  def initialize(attrs = {})
    @credentials = attrs
  end

  def username_key
    credentials.fetch('username', {}).fetch('key', nil)
  end

  def username_value(guid)
    if username_value = credentials.fetch('username', {}).fetch('value', nil)
      username_value
    else
      Digest::MD5.base64digest("#{USERNAME_PREFIX}-#{guid}").gsub(/[^a-zA-Z0-9]+/, '')[0...16].downcase
    end
  end

  def password_key
    credentials.fetch('password', {}).fetch('key', nil)
  end

  def password_value(guid)
    if password_value = credentials.fetch('password', {}).fetch('value', nil)
      password_value
    else
      Digest::MD5.base64digest("#{PASSWORD_PREFIX}-#{guid}").gsub(/[^a-zA-Z0-9]+/, '')[0...16].downcase
    end
  end

  def dbname_key
    credentials.fetch('dbname', {}).fetch('key', nil)
  end

  def dbname_value(guid)
    if dbname_value = credentials.fetch('dbname', {}).fetch('value', nil)
      dbname_value
    else
      Digest::MD5.base64digest("#{DBNAME_PREFIX}-#{guid}").gsub(/[^a-zA-Z0-9]+/, '')[0...16].downcase
    end
  end

  def uri_prefix
    credentials.fetch('uri', {}).fetch('prefix', nil)
  end

  def uri_port
    credentials.fetch('uri', {}).fetch('port', nil)
  end

  def to_hash(guid, hostname, ports)
    service_credentials = { 'hostname' => hostname }

    service_credentials['ports'] = ports unless ports.empty?
    if uri_port
      if port = ports.fetch(uri_port, nil)
        service_credentials['port'] = port
      else
        Rails.logger.info("+-> Credentials #{uri_port} is not exposed")
      end
    elsif ports.size == 1
      service_credentials['port'] = ports.values[0]
    end

    service_credentials['username'] = username_value(guid) if username_key
    service_credentials['password'] = password_value(guid) if password_key
    service_credentials['dbname'] = dbname_value(guid) if dbname_key

    if uri_prefix
      uri = "#{uri_prefix}://"
      if service_credentials['username']
        uri << service_credentials['username']
        uri << ":#{service_credentials['password']}" if service_credentials['password']
        uri << '@'
      end
      uri << service_credentials['hostname']
      uri << ":#{service_credentials['port']}" if service_credentials['port']
      uri << "/#{service_credentials['dbname']}" if service_credentials['dbname']

      service_credentials['uri'] = uri
    end

    service_credentials
  end
end
