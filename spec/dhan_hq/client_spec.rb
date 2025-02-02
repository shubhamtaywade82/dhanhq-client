# frozen_string_literal: true

require "vcr"

RSpec.describe DhanHQ::Client do
  let(:client) { described_class.new }
  let(:marketquote_request_params) do
    {
      NSE_FNO: [49_081]
    }
  end
  let(:ltp_request_params) do
    {
      instruments: ["NSE:INFY"],
      fields: ["lastPrice"]
    }
  end
  let(:ohlc_request_params) do
    {
      instruments: ["NSE:INFY"],
      fields: ["ohlc"]
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
      securityId: "133",
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

  describe "#request" do
    it "sends headers correctly for /marketfeed/ltp", vcr: { cassette_name: "client/marketfeed_ltp" } do
      response = client.post("/v2/marketfeed/ltp", ltp_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for /marketfeed/ohlc", vcr: { cassette_name: "client/marketfeed_ohlc" } do
      response = client.post("/v2/marketfeed/ohlc", ohlc_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for /marketfeed/quote", vcr: { cassette_name: "client/market_quote" } do
      response = client.post("/v2/marketfeed/quote", marketquote_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for /optionchain", vcr: { cassette_name: "client/optionchain" } do
      response = client.post("/v2/optionchain", option_chain_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for /optionchain/expirylist", vcr: { cassette_name: "client/optionchain_expirylist" } do
      response = client.post("/v2/optionchain/expirylist", expiry_list_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for non-DATA APIs", vcr: { cassette_name: "client/margin_calculator" } do
      response = client.post("/v2/margincalculator", margin_calculator_request_params)
      expect(response).to include("insufficientBalance" => 0.0)
    end
  end

  describe "#build_headers" do
    it "includes client-id for /marketfeed/ltp" do
      headers = client.send(:build_headers, "/v2/marketfeed/ltp")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "includes client-id for /marketfeed/ohlc" do
      headers = client.send(:build_headers, "/v2/marketfeed/ohlc")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "includes client-id for /marketfeed/quote" do
      headers = client.send(:build_headers, "/v2/marketfeed/quote")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "includes client-id for /optionchain" do
      headers = client.send(:build_headers, "/v2/optionchain")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "includes client-id for /optionchain/expirylist" do
      headers = client.send(:build_headers, "/v2/optionchain/expirylist")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end
  end

  describe "#get", vcr: { cassette_name: "dhan_hq_get_request" } do
    it "sends a GET request and returns the response" do
      response = client.get("/orders")
      expect(response).to be_a(Array)
    end
  end

  describe "#post", vcr: { cassette_name: "dhan_hq_post_request" } do
    it "sends a POST request and returns the response" do
      response = client.post("/v2/charts/historical", historical_request_params)
      expect(response).to include("close" => [1664.9])
    end
  end

  describe "error handling" do
    context "when the access token is not set" do
      before do
        DhanHQ.configure do |config|
          config.access_token = "access_token"
          config.client_id = "client_id"
        end
      end

      it "raises a DhanHQ::InvalidAuthenticationError for DH-901", vcr: { cassette_name: "client/error_dh_901" } do
        expect do
          client.get("/v2/orders")
        end.to raise_error(DhanHQ::InvalidAuthenticationError, /InvalidAuthentication: 401:/)
      end
    end

    it "raises a DhanHQ::InputExceptionError for DH-905", vcr: { cassette_name: "client/error_dh_905" } do
      expect do
        client.post("/v2/orders", { invalid_param: true })
      end.to raise_error(DhanHQ::InputExceptionError, /InputException: 400/)
    end

    it "raises a DhanHQ::RateLimitError for DH-904", vcr: { cassette_name: "client/error_dh_904" } do
      expect do
        client.post("/v2/marketfeed/quote")
      end.to raise_error(DhanHQ::RateLimitError, /RateLimit: 429:/)
    end

    it "raises a DhanHQ::Error for an unknown error code", vcr: { cassette_name: "client/error_unknown" } do
      expect do
        client.get("/v2/unknown_error_endpoint")
      end.to raise_error(DhanHQ::Error, /Not Found:/)
    end

    it "raises an error for invalid payload types", vcr: { cassette_name: "client/error_invalid_payload" } do
      expect do
        client.post("/v2/orders", { invalid: "data" }) # ✅ Now using a Hash
      end.to raise_error(DhanHQ::InputExceptionError, /InputException: 400/)
    end

    it "handles large payload responses", vcr: { cassette_name: "client/large_payload" } do
      response = client.post("/v2/marketfeed/quote", { NSE_FNO: (1..1000).to_a })
      expect(response).to be_a(Hash)
      expect(response.keys).to include("status", "data")
    end
  end
end
