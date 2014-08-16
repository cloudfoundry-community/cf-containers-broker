# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe ContainerImages do
  let(:subject) { described_class }
  let(:plans) { [plan] }
  let(:plan) { double('Plan') }
  let(:container_manager) { double('ContainerManager') }

  describe '#fetch' do
    it 'fetches the image using the container manager' do
      expect(Catalog).to receive(:plans).and_return(plans)
      expect(plan).to receive(:container_manager).and_return(container_manager)
      expect(container_manager).to receive(:fetch_image)

      subject.fetch
    end

    context 'when the catalog is empty' do
      it 'does nothing' do
        expect(Catalog).to receive(:plans).and_return([])

        subject.fetch
      end
    end
  end
end
