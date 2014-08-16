# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe V2::CatalogsController do
  before do
    authenticate
  end

  describe '#show' do
    let(:make_request) { get :show }
    let(:services) { [service_1, service_2] }
    let(:service_1) { double( 'Service', to_hash: { 'id' => 'service-1' }) }
    let(:service_2) { double( 'Service', to_hash: { 'id' => 'service-2' }) }

    before do
      allow(Catalog).to receive(:services).and_return(services)
    end

    it_behaves_like 'a controller action that requires basic auth'

    it_behaves_like 'a controller action that logs its request and response headers and body'

    context 'there are services at the catalog' do
      it 'builds services from the values in Settings' do
        make_request

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          {
            'services' => [
              { 'id' => 'service-1' },
              { 'id' => 'service-2' },
            ]
          }
        )
      end
    end

    context 'with an empty catalog' do
      let(:services) { [] }

      context 'when there are no services' do
        it 'produces an empty catalog' do
          make_request

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).to eq({ 'services' => []})
        end
      end
    end
  end
end
