# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require Rails.root.join('lib/exceptions')
require 'docker'
require 'singleton'

class DockerHostPortAllocator
  include Singleton

  attr_reader :allocated_ports, :port_range_start, :port_range_end

  def allocate_host_port(protocol)
    # We get used ports the 1st time this instance is invoked, as
    # we are assuming no other service beyond this broker is
    # going to allocate host ports
    unless allocated_ports
      set_dynamic_port_range
      get_used_ports
    end

    (port_range_start..port_range_end).each do |port|
      unless allocated_ports[protocol] && allocated_ports[protocol].include?(port)
        @allocated_ports[protocol] ||= []
        @allocated_ports[protocol] << port
        return port
      end
    end

    raise Exceptions::BackendError, 'All dynamic ports have been exhausted!'
  end

  private

  def set_dynamic_port_range
    # Ephemeral port range: http://www.ncftp.com/ncftpd/doc/misc/ephemeral_ports.html
    # We assume all nodes in the cluster have the same ephemeral port range
    ephemeral_port_range = File.read('/proc/sys/net/ipv4/ip_local_port_range')
    port_range = ephemeral_port_range.split()
    @port_range_start = port_range.first.to_i
    @port_range_end   = port_range.last.to_i
  rescue
    @port_range_start = 32768
    @port_range_end   = 61000
  end

  def get_used_ports
    @allocated_ports = {}
    containers = Docker::Container.all
    containers.each do |container|
      ports = container.info.fetch('Ports', {})
      ports.each do |port|
        if public_port = port['PublicPort']
          protocol = port['Type']
          @allocated_ports[protocol] ||= []
          @allocated_ports[protocol] << public_port
        end
      end
    end
  end

end
