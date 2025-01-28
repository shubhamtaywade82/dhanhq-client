# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::HistoricalData do
  let(:historical_data) { described_class.new }

  let(:daily_params) do
    {
      securityId: "1333",
      exchangeSegment: "NSE_EQ",
      instrument: "EQUITY",
      fromDate: "2022-01-08",
      toDate: "2022-02-08"
    }
  end

  let(:intraday_params) do
    {
      securityId: "1333",
      exchangeSegment: "NSE_EQ",
      instrument: "EQUITY",
      interval: "1",
      fromDate: "2024-09-11",
      toDate: "2024-09-15"
    }
  end

  before do
    DhanHQ.configure_with_env
  end

  describe "#fetch_daily_data" do
    it "fetches daily OHLC data successfully", :vcr do
      VCR.use_cassette("resources/historical_data_daily") do
        response = historical_data.fetch_daily_data(daily_params)
        expect(response["open"]).to include(1561.55)
        expect(response["high"]).to include(1555.0)
      end
    end
  end

  describe "#fetch_intraday_data" do
    it "fetches intraday OHLC data successfully", :vcr do
      VCR.use_cassette("resources/historical_data_intraday") do
        response = historical_data.fetch_intraday_data(intraday_params)
        expect(response["open"]).to include(1650.4)
        expect(response["high"]).to include(1650.8)
      end
    end
  end
end
