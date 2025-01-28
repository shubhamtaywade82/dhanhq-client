# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Trades do
  let(:trades) { described_class.new }

  let(:mock_trade_list_response) do
    [
      {
        dhanClientId: "1000000009",
        orderId: "112111182045",
        exchangeOrderId: "15112111182045",
        exchangeTradeId: "15112111182045",
        transactionType: "BUY",
        exchangeSegment: "NSE_EQ",
        productType: "INTRADAY",
        orderType: "LIMIT",
        tradingSymbol: "TCS",
        securityId: "11536",
        tradedQuantity: 40,
        tradedPrice: 3345.8,
        createTime: "2021-03-10 11:20:06",
        updateTime: "2021-11-25 17:35:12",
        exchangeTime: "2021-11-25 17:35:12",
        drvExpiryDate: nil,
        drvOptionType: nil,
        drvStrikePrice: 0.0
      }
    ].to_json
  end

  let(:mock_trade_details_response) do
    {
      dhanClientId: "1000000009",
      orderId: "112111182045",
      exchangeOrderId: "15112111182045",
      exchangeTradeId: "15112111182045",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "LIMIT",
      tradingSymbol: "TCS",
      securityId: "11536",
      tradedQuantity: 40,
      tradedPrice: 3345.8,
      createTime: "2021-03-10 11:20:06",
      updateTime: "2021-11-25 17:35:12",
      exchangeTime: "2021-11-25 17:35:12",
      drvExpiryDate: nil,
      drvOptionType: nil,
      drvStrikePrice: 0.0
    }.to_json
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
    end

    stub_request(:get, "https://api.dhan.co/v2/trades")
      .to_return(
        status: 200,
        body: mock_trade_list_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.dhan.co/v2/trades/112111182045")
      .to_return(
        status: 200,
        body: mock_trade_details_response,
        headers: { "Content-Type" => "application/json" }
      )
  end

  after { VCR.turn_on! }

  describe "#fetch_trades" do
    it "fetches the list of all trades for the day" do
      response = trades.fetch_trades
      expect(response).to be_an(Array)
      expect(response.first[:orderId]).to eq("112111182045")
      expect(response.first[:transactionType]).to eq("BUY")
    end
  end

  describe "#fetch_trades_by_order" do
    it "fetches trade details for a specific order ID" do
      response = trades.fetch_trades_by_order("112111182045")
      expect(response[:orderId]).to eq("112111182045")
      expect(response[:transactionType]).to eq("BUY")
      expect(response[:tradedPrice]).to eq(3345.8)
    end
  end
end
