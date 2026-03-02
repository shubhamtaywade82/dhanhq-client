# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::Holdings do
  subject(:resource) { described_class.new }

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#all" do
    let(:holdings_list) do
      [
        { "securityId" => "1333", "exchangeSegment" => "NSE_EQ", "tradingSymbol" => "HDFC", "totalQty" => 10 },
        { "securityId" => "2881", "exchangeSegment" => "NSE_EQ", "tradingSymbol" => "RELIANCE", "totalQty" => 5 }
      ]
    end

    before do
      stub_request(:get, "https://api.dhan.co/v2/holdings")
        .to_return(status: 200, body: holdings_list.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array" do
      expect(resource.all).to be_an(Array)
    end

    it "returns the expected number of holdings" do
      expect(resource.all.length).to eq(2)
    end
  end
end
