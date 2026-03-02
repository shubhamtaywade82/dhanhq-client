# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::HistoricalData do
  subject(:resource) { described_class.new }

  let(:ohlc_response) do
    {
      "open" => [1480.0, 1485.0],
      "high" => [1510.0, 1512.0],
      "low" => [1470.0, 1475.0],
      "close" => [1500.0, 1505.0],
      "volume" => [100_000, 95_000],
      "start_Time" => [1_700_000_000, 1_700_086_400]
    }
  end

  let(:daily_params) do
    { security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY",
      from_date: "2025-01-01", to_date: "2025-01-31" }
  end

  let(:intraday_params) do
    daily_params.merge(interval: "15")
  end

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#daily" do
    before do
      stub_request(:post, "https://api.dhan.co/v2/charts/historical")
        .to_return(status: 200, body: ohlc_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash with OHLC arrays" do
      result = resource.daily(daily_params)
      expect(result).to be_a(Hash)
    end

    it "includes open prices" do
      result = resource.daily(daily_params)
      expect(result).to have_key("open")
    end
  end

  describe "#intraday" do
    before do
      stub_request(:post, "https://api.dhan.co/v2/charts/intraday")
        .to_return(status: 200, body: ohlc_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash with OHLC arrays" do
      result = resource.intraday(intraday_params)
      expect(result).to be_a(Hash)
    end
  end
end
