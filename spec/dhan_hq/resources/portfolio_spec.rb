# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Portfolio do
  let(:portfolio) { described_class.new }

  let(:mock_holdings_response) do
    [
      {
        exchange: "NSE_EQ",
        tradingSymbol: "HDFC",
        securityId: "1330",
        isin: "INE001A01036",
        totalQty: 1000,
        dpQty: 1000,
        t1Qty: 0,
        availableQty: 1000,
        collateralQty: 0,
        avgCostPrice: 2655.0
      }
    ].to_json
  end

  let(:mock_positions_response) do
    [
      {
        dhanClientId: "1000000009",
        tradingSymbol: "TCS",
        securityId: "11536",
        positionType: "LONG",
        exchangeSegment: "NSE_EQ",
        productType: "CNC",
        buyAvg: 3345.8,
        buyQty: 40,
        costPrice: 3215.0,
        sellAvg: 0.0,
        sellQty: 0,
        netQty: 40,
        realizedProfit: 0.0,
        unrealizedProfit: 6122.0,
        rbiReferenceRate: 1.0,
        multiplier: 1
      }
    ].to_json
  end

  let(:mock_convert_response) { "202 Accepted" }

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
      config.client_id = "test_client_id"
    end

    stub_request(:get, "https://api.dhan.co/v2/holdings")
      .to_return(
        status: 200,
        body: mock_holdings_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.dhan.co/v2/positions")
      .to_return(
        status: 200,
        body: mock_positions_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.dhan.co/v2/positions/convert")
      .to_return(
        status: 202,
        body: mock_convert_response,
        headers: { "Content-Type" => "text/plain" }
      )
  end

  after { VCR.turn_on! }

  describe "#holdings" do
    it "retrieves the list of holdings successfully" do
      response = portfolio.holdings
      expect(response).to be_an(Array)
      expect(response.first["tradingSymbol"]).to eq("HDFC")
      expect(response.first["avgCostPrice"]).to eq(2655.0)
    end
  end

  describe "#positions" do
    it "retrieves the list of positions successfully" do
      response = portfolio.positions
      expect(response).to be_an(Array)
      expect(response.first["tradingSymbol"]).to eq("TCS")
      expect(response.first["positionType"]).to eq("LONG")
    end
  end

  describe "#convert_position" do
    it "converts a position successfully" do
      conversion_params = {
        dhanClientId: "1000000009",
        fromProductType: "INTRADAY",
        exchangeSegment: "NSE_EQ",
        positionType: "LONG",
        securityId: "11536",
        convertQty: 40,
        toProductType: "CNC"
      }

      response = portfolio.convert_position(conversion_params)
      expect(response).to eq({})
    end
  end
end
