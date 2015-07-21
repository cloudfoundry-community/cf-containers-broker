# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe DockerHostPortAllocator do
  describe '#allocate_host_port' do
    let(:subject) {described_class.send(:new) }
    let(:port_range_start) { 50000 }
    let(:port_range_end) { 60000 }
    let(:ephemeral_ports) { "#{port_range_start} #{port_range_end}" }
    let(:containers) { {} }

    before do
      allow(Docker::Container).to receive(:all).and_return(containers)
    end

    context 'when ephemeral ports file exists' do
      before do
        allow(File).to receive(:read).with('/proc/sys/net/ipv4/ip_local_port_range').and_return(ephemeral_ports)
      end

      it 'sets the ephemeral port range to the contents of the ephemeral ports file' do
        subject.allocate_host_port('tcp')
        expect(subject.port_range_start).to eq(port_range_start)
        expect(subject.port_range_end).to eq(port_range_end)
      end
    end

    context 'when ephemeral ports file does not exists' do
      before do
        allow(File).to receive(:read).with('/proc/sys/net/ipv4/ip_local_port_range').and_raise(Errno::ENOENT)
      end

      it 'sets the ephemeral port range to the defaults' do
        subject.allocate_host_port('tcp')
        expect(subject.port_range_start).to eq(32768)
        expect(subject.port_range_end).to eq(61000)
      end
    end

    context 'when there are not any container running' do
      it 'allocates consecutive ports' do
        expect(subject.allocate_host_port('tcp')).to eq(32768)
        expect(subject.allocate_host_port('tcp')).to eq(32769)
        expect(subject.allocate_host_port('tcp')).to eq(32770)
      end
    end

    context 'when there are containers running' do
      let(:container) { double(Docker::Container, info: { 'Ports' => [{'PublicPort' => 32768, 'Type' => 'udp'}, {'PublicPort' => 32769, 'Type' => 'tcp'}] }) }
      let(:containers) { [container] }

      it 'should skip already used ports' do
        expect(subject.allocate_host_port('tcp')).to eq(32768)
        expect(subject.allocate_host_port('tcp')).to eq(32770)
      end
    end

    context 'when ports are exhausted' do
      let(:port_range_start) { 50000 }
      let(:port_range_end) { 50000 }

      before do
        allow(File).to receive(:read).with('/proc/sys/net/ipv4/ip_local_port_range').and_return(ephemeral_ports)
      end

      it 'raises a BackendError exception' do
        expect(subject.allocate_host_port('tcp')).to eq(port_range_start)
        expect do
          subject.allocate_host_port('tcp')
         end.to raise_error Exceptions::BackendError, 'All dynamic ports have been exhausted!'
      end
    end
  end
end
