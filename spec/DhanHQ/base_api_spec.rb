# frozen_string_literal: true

require "vcr"

RSpec.describe DhanHQ::BaseAPI do
  let(:ltp_request_params) do
    {
      instruments: ["NSE:INFY"],
      fields: ["lastPrice"]
    }
  end
  let(:ohlc_request_params) do
    {
      NSE_FNO: [
        49_081
      ]
    }
  end
  let(:marketquote_request_params) do
    {
      NSE_FNO: [49_081]
    }
  end
  let(:option_chain_request_params) do
    {
      UnderlyingScrip: 13,
      UnderlyingSeg: "IDX_I",
      Expiry: "2025-01-30"
    }
  end
  let(:expiry_list_request_params) do
    {
      UnderlyingScrip: 13,
      UnderlyingSeg: "IDX_I"
    }
  end
  let(:historical_request_params) do
    {
      securityId: "1333",
      exchangeSegment: "NSE_EQ",
      instrument: "EQUITY",
      expiryCode: 0,
      fromDate: "2025-01-23",
      toDate: "2025-01-24"
    }
  end
  let(:margin_calculator_request_params) do
    {
      dhanClientId: "1000000132",
      exchangeSegment: "NSE_EQ",
      transactionType: "BUY",
      quantity: 5,
      productType: "CNC",
      securityId: "1333",
      price: 1428,
      triggerPrice: 1427
    }
  end

  before do
    DhanHQ.configure_with_env
  end

  describe "MarketFeed APIs" do
    it "fetches LTP data", vcr: { cassette_name: "base_api/marketfeed_ltp" } do
      api = MarketFeedLTP.new
      response = api.fetch(ltp_request_params)
      expect(response).to include("status" => "success")
    end

    it "fetches OHLC data", vcr: { cassette_name: "base_api/marketfeed_ohlc" } do
      api = MarketFeedOHLC.new
      response = api.fetch(ohlc_request_params)
      expect(response).to include("status" => "success")
    end

    it "fetches quote data", vcr: { cassette_name: "base_api/marketfeed_quote" } do
      api = MarketFeedQuote.new
      response = api.fetch(marketquote_request_params)
      expect(response).to include("status" => "success")
    end
  end

  describe "OptionChain APIs" do
    it "fetches option chain data", vcr: { cassette_name: "base_api/optionchain" } do
      api = OptionChain.new
      response = api.fetch(option_chain_request_params)
      expect(response).to include("status" => "success")
    end

    it "fetches expiry list data", vcr: { cassette_name: "base_api/optionchain_expirylist" } do
      api = OptionChainExpiryList.new
      response = api.fetch(expiry_list_request_params)
      expect(response).to include("status" => "success")
    end
  end

  describe "Margin Calculator API" do
    it "calculates margin", vcr: { cassette_name: "base_api/margin_calculator" } do
      api = MarginCalculator.new
      response = api.calculate(margin_calculator_request_params)
      expect(response).to include("insufficientBalance" => 0.0)
    end
  end

  describe "Charts Historical API" do
    it "fetches historical chart data", vcr: { cassette_name: "base_api/charts_historical" } do
      api = ChartsHistorical.new
      response = api.fetch(historical_request_params)
      expect(response).to include("close" => [1664.9])
    end
  end
end
