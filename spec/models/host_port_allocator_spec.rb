# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe HostPortAllocator do
  before { FileUtils.rm_rf('/tmp/host_port_counter') }
  let(:subject) { described_class.new('/tmp', 10000, 10004) }
  it 'should allocate consecutive ports and wrap around' do
    expect(subject.send(:allocate_next_port)).to eq(10000)
    expect(subject.send(:allocate_next_port)).to eq(10001)
    expect(subject.send(:allocate_next_port)).to eq(10002)
    expect(subject.send(:allocate_next_port)).to eq(10003)
    expect(subject.send(:allocate_next_port)).to eq(10004)
    expect(subject.send(:allocate_next_port)).to eq(10000)
  end
end
