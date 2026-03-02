# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::Orders do
  subject(:resource) { described_class.new }

  let(:base_url) { "https://api.dhan.co/v2/orders" }
  let(:order_response) { { "orderId" => "ORD001", "status" => "PENDING" } }
  let(:orders_list) { [order_response, order_response.merge("orderId" => "ORD002")] }

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#all" do
    before do
      stub_request(:get, base_url)
        .to_return(status: 200, body: orders_list.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array" do
      expect(resource.all).to be_an(Array)
    end

    it "returns the expected number of orders" do
      expect(resource.all.length).to eq(2)
    end
  end

  describe "#find" do
    before do
      stub_request(:get, "#{base_url}/ORD001")
        .to_return(status: 200, body: order_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash for the given order_id" do
      result = resource.find("ORD001")
      expect(result).to be_a(Hash)
      expect(result["orderId"]).to eq("ORD001")
    end
  end

  describe "#create" do
    let(:params) do
      { transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
        order_type: "LIMIT", validity: "DAY", security_id: "1333", quantity: 1, price: 100.0 }
    end

    before do
      stub_request(:post, base_url)
        .to_return(status: 200, body: order_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash with orderId" do
      result = resource.create(params)
      expect(result).to be_a(Hash)
      expect(result["orderId"]).to eq("ORD001")
    end
  end

  describe "#update" do
    before do
      stub_request(:put, "#{base_url}/ORD001")
        .to_return(status: 200, body: order_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.update("ORD001", { quantity: 2 })
      expect(result).to be_a(Hash)
    end
  end

  describe "#cancel" do
    before do
      stub_request(:delete, "#{base_url}/ORD001")
        .to_return(status: 200, body: { "orderId" => "ORD001", "status" => "CANCELLED" }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.cancel("ORD001")
      expect(result).to be_a(Hash)
    end
  end

  describe "#slicing" do
    before do
      stub_request(:post, "#{base_url}/slicing")
        .to_return(status: 200, body: [order_response].to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of sliced orders" do
      result = resource.slicing({ security_id: "1333", quantity: 10 })
      expect(result).to be_an(Array)
    end
  end

  describe "#by_correlation" do
    before do
      stub_request(:get, "#{base_url}/external/COR123")
        .to_return(status: 200, body: order_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash for the given correlation_id" do
      result = resource.by_correlation("COR123")
      expect(result).to be_a(Hash)
    end
  end
end
