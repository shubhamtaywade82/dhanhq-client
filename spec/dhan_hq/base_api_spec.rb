# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::BaseAPI do
  let(:api_type) { :order_api }
  let(:base_api) { described_class.new(api_type: api_type) }
  let(:endpoint) { "/v2/orders" }
  let(:order_id) { "112111182198" }
  let(:params) { { dhanClientId: "1000000003", orderId: order_id } }

  let(:order_payload) do
    {
      dhanClientId: "1000000003",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "MARKET",
      validity: "DAY",
      securityId: "11536",
      quantity: 5
    }
  end

  before do
    DhanHQ.configure_with_env
  end

  describe "#initialize" do
    it "initializes with the correct API type" do
      expect(base_api.client).to be_a(DhanHQ::Client)
    end
  end

  describe "#get", vcr: { cassette_name: "base_api/get_request" } do
    let(:endpoint) { "/v2/orders/#{order_id}" }

    it "retrieves order details successfully" do
      response = base_api.get(endpoint)
      expect(response).to be_a(Hash)
      expect(response).to include("orderId" => order_id, "orderStatus" => "PENDING")
    end
  end

  describe "#post", vcr: { cassette_name: "base_api/post_request" } do
    let(:endpoint) { "/v2/orders" }

    it "places a new order successfully" do
      response = base_api.post(endpoint, params: order_payload)
      expect(response).to be_a(Hash)
      expect(response).to include("orderId", "orderStatus")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#put", vcr: { cassette_name: "base_api/put_request" } do
    let(:endpoint) { "/v2/orders/#{order_id}" }
    let(:update_params) { { quantity: 10, price: 1200.5 } }

    it "modifies an existing order" do
      response = base_api.put(endpoint, params: update_params)
      expect(response).to be_a(Hash)
      expect(response).to include("orderId" => order_id, "orderStatus" => "PENDING")
    end
  end

  describe "#delete", vcr: { cassette_name: "base_api/delete_request" } do
    let(:endpoint) { "/v2/orders/#{order_id}" }

    it "cancels an existing order" do
      response = base_api.delete(endpoint)
      expect(response).to be_a(Hash)
      expect(response).to include("orderId" => order_id, "orderStatus" => "CANCELLED")
    end
  end

  describe "#handle_response" do
    it "returns response when it's a valid Hash" do
      response = base_api.send(:handle_response, { success: true })
      expect(response).to eq({ success: true })
    end

    it "returns response when it's a valid Array" do
      response = base_api.send(:handle_response, [{ success: true }])
      expect(response).to eq([{ success: true }])
    end

    it "raises an error for invalid response format" do
      expect { base_api.send(:handle_response, "invalid response") }
        .to raise_error(DhanHQ::Error, "Unexpected API response format")
    end
  end
end
