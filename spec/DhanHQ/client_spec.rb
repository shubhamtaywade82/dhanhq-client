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

  before do
    DhanHQ.configure_with_env
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
