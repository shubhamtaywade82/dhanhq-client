# frozen_string_literal: true

require "vcr"

RSpec.describe DhanHQ::BaseModel do
  # Use real API credentials from environment
  before do
    DhanHQ.configure_with_env
    skip "No API credentials configured" unless DhanHQ.configuration.access_token
  end

  describe "Real API Integration" do
    it "fetches historical data successfully", vcr: { cassette_name: "base_model/historical_data_test" } do
      data = DhanHQ::Models::HistoricalData.intraday(
        security_id: "13",
        exchange_segment: "IDX_I",
        instrument: "INDEX",
        interval: "5",
        from_date: "2024-01-15",
        to_date: "2024-01-16"
      )

      expect(data).to be_a(Hash)
      expect(data["close"]).to be_an(Array)
      expect(data["close"]).not_to be_empty
    end

    it "returns proper OHLC data structure", vcr: { cassette_name: "base_model/historical_data_test" } do
      data = DhanHQ::Models::HistoricalData.intraday(
        security_id: "13",
        exchange_segment: "IDX_I",
        instrument: "INDEX",
        interval: "5",
        from_date: "2024-01-15",
        to_date: "2024-01-16"
      )

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

    describe "#delete and #destroy" do
      it "delegates delete to destroy" do
        # Use a test model class since Order aliases delete to destroy (they're the same method)
        test_model_class = Class.new(DhanHQ::BaseModel) do
          def self.validation_contract
            nil
          end

          def self.resource
            @resource ||= DhanHQ::BaseAPI.new
          end
        end
        model = test_model_class.new({ id: "123" }, skip_validation: true)
        # Stub destroy to avoid making HTTP request
        allow(model).to receive(:destroy).and_return(true)
        result = model.delete
        expect(result).to be true
        expect(model).to have_received(:destroy)
      end

      it "logs errors when destroy fails" do
        # Use a test model class to test BaseModel's destroy (Order overrides it without rescue)
        test_model_class = Class.new(DhanHQ::BaseModel) do
          def self.validation_contract
            nil
          end

          def self.resource
            @resource ||= DhanHQ::BaseAPI.new
          end
        end
        model = test_model_class.new({ id: "123" }, skip_validation: true)
        allow(model.class.resource).to receive(:delete).and_raise(StandardError.new("Test error"))
        expect(DhanHQ.logger).to receive(:error).with(/Error deleting resource/)
        expect(model.destroy).to be false
      end
    end

    describe "#parse_collection_response" do
      it "logs warning for unexpected response formats" do
        expect(DhanHQ.logger).to receive(:warn).with(/Unexpected response format/)
        result = described_class.parse_collection_response("invalid")
        expect(result).to eq([])
      end

      it "handles array responses" do
        response = [{ id: 1 }, { id: 2 }]
        result = described_class.parse_collection_response(response)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it "handles hash with data key" do
        response = { data: [{ id: 1 }] }
        result = described_class.parse_collection_response(response)
        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
      end
    end

    describe "#id" do
      it "converts id to string" do
        model = described_class.new({ id: 123 }, skip_validation: true)
        expect(model.id).to eq("123")
      end

      it "handles order_id" do
        model = described_class.new({ order_id: 456 }, skip_validation: true)
        expect(model.id).to eq("456")
      end

      it "returns nil when no id present" do
        model = described_class.new({}, skip_validation: true)
        expect(model.id).to be_nil
      end
    end
  end
end
