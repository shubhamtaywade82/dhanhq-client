# frozen_string_literal: true

# spec/dhan_hq/client_spec.rb

require "vcr"

RSpec.describe DhanHQ::Client do
  let(:client) { described_class.new }

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

  let(:marketquote_request_params) do
    {
      NSE_FNO: [49_081]
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
    it "sends headers correctly for DATA APIs", vcr: { cassette_name: "client/market_quote" } do
      response = client.post("/v2/marketfeed/quote", marketquote_request_params)
      expect(response).to include("status" => "success")
    end

    it "sends headers correctly for non-DATA APIs", vcr: { cassette_name: "client/margin_calculator" } do
      response = client.post("/v2/margincalculator", margin_calculator_request_params)
      expect(response).to include("insufficientBalance" => 0.0)
    end
  end

  describe "#build_headers" do
    it "includes client-id for DATA APIs" do
      headers = client.send(:build_headers, "/marketfeed/quote")
      expect(headers).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "does not include client-id for non-DATA APIs" do
      headers = client.send(:build_headers, "/orders")
      expect(headers).not_to include("client-id")
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
      expect(response).to include("success" => true)
    end
  end

  # describe "#put", vcr: { cassette_name: "dhan_hq_put_request" } do
  #   it "sends a PUT request and returns the response" do
  #     # VCR.use_cassette("dhan_hq_put_request") do
  #       response = client.put("/test_endpoint", { param1: "value1" })
  #       expect(response).to include("success" => true)
  #     # end
  #   end
  # end

  # describe "#delete", vcr: { cassette_name: "dhan_hq_delete_request" } do
  #   it "sends a DELETE request and returns the response" do
  #     # VCR.use_cassette("dhan_hq_delete_request") do
  #       response = client.delete("/test_endpoint", { param1: "value1" })
  #       expect(response).to include("success" => true)
  #     # end
  #   end
  # end

  # describe "error handling" do
  #   it "raises a DhanHQ::Error for a 400 response", vcr: { cassette_name: "dhan_hq_error_400" } do
  #     # VCR.use_cassette("dhan_hq_error_400") do
  #       expect { client.get("/test_endpoint") }.to raise_error(DhanHQ::Error, /Bad Request/)
  #     # end
  #   end

  #   it "raises a DhanHQ::Error for a 500 response", vcr: { cassette_name: "dhan_hq_error_500" } do
  #     # VCR.use_cassette("dhan_hq_error_500") do
  #       expect { client.get("/test_endpoint") }.to raise_error(DhanHQ::Error, /Server Error/)
  #     # end
  #   end
  # end
end
