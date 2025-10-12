# frozen_string_literal: true

require "vcr"

RSpec.describe DhanHQ::BaseModel do
  # Use real API credentials from environment
  before do
    DhanHQ.configure_with_env
    skip "No API credentials configured" unless DhanHQ.configuration.access_token
  end

  describe "Real API Integration" do
    it "works with actual DhanHQ models", vcr: { cassette_name: "base_model/historical_data_test" } do
      # Test with a real model like HistoricalData
      data = DhanHQ::Models::HistoricalData.intraday(
        security_id: "13",
        exchange_segment: "IDX_I",
        instrument: "INDEX",
        interval: "5",
        from_date: "2024-01-15",
        to_date: "2024-01-15"
      )

      expect(data).to be_a(Hash)
      expect(data["close"]).to be_an(Array)
      expect(data["close"]).not_to be_empty
      expect(data["open"]).to be_an(Array)
      expect(data["high"]).to be_an(Array)
      expect(data["low"]).to be_an(Array)
    end

    it "works with MarketFeed LTP", vcr: { cassette_name: "base_model/market_feed_test" } do
      response = DhanHQ::Models::MarketFeed.ltp(
        instruments: ["NSE:INFY"],
        fields: ["lastPrice"]
      )

      expect(response["status"]).to eq("success")
      expect(response["data"]).to be_a(Hash)
    end

    it "validates input parameters" do
      # Test that validation works with invalid data
      expect do
        DhanHQ::Models::HistoricalData.intraday(
          security_id: nil,
          exchange_segment: "",
          instrument: nil,
          interval: "5",
          from_date: "2024-01-15",
          to_date: "2024-01-15"
        )
      end.to raise_error(DhanHQ::Error, /Validation Error/)
    end

    it "converts snake_case to camelCase for API requests" do
      # Test with a model that has attributes like Order
      model = DhanHQ::Models::Order.new({
                                          dhan_client_id: "12345",
                                          transaction_type: "BUY",
                                          product_type: "CNC"
                                        }, skip_validation: true)

      params = model.to_request_params
      expect(params).to include(
        "dhanClientId" => "12345",
        "transactionType" => "BUY",
        "productType" => "CNC"
      )
    end
  end
end
