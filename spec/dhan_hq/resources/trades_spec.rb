# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::Trades do
  subject(:resource) { described_class.new }

  let(:trade) { { "orderId" => "ORD001", "tradedQty" => 10, "tradedPrice" => 1500.0 } }

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#all" do
    before do
      stub_request(:get, "https://api.dhan.co/v2/trades")
        .to_return(status: 200, body: [trade].to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of trades" do
      expect(resource.all).to be_an(Array)
    end
  end

  describe "#find" do
    before do
      stub_request(:get, "https://api.dhan.co/v2/trades/ORD001")
        .to_return(status: 200, body: [trade].to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns the trade for the given order_id" do
      result = resource.find("ORD001")
      expect(result).to be_an(Array)
    end
  end
end
