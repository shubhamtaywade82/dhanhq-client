# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::SuperOrders do
  subject(:resource) { described_class.new }

  let(:base_url) { "https://api.dhan.co/v2/super/orders" }
  let(:super_order) { { "orderId" => "SO001", "status" => "PENDING" } }

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#all" do
    before do
      stub_request(:get, base_url)
        .to_return(status: 200, body: [super_order].to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array" do
      expect(resource.all).to be_an(Array)
    end
  end

  describe "#create" do
    before do
      stub_request(:post, base_url)
        .to_return(status: 200, body: super_order.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.create({ security_id: "1333", quantity: 1 })
      expect(result).to be_a(Hash)
    end
  end

  describe "#update" do
    before do
      stub_request(:put, "#{base_url}/SO001")
        .to_return(status: 200, body: super_order.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.update("SO001", { quantity: 2 })
      expect(result).to be_a(Hash)
    end
  end

  describe "#cancel" do
    before do
      stub_request(:delete, "#{base_url}/SO001/ENTRY")
        .to_return(status: 200, body: { "orderId" => "SO001", "status" => "CANCELLED" }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.cancel("SO001", "ENTRY")
      expect(result).to be_a(Hash)
    end
  end
end
