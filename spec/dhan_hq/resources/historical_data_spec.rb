# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::HistoricalData do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/charts" }
  let(:chart_body) do
    {
      open: [2450.1, 2461.0],
      high: [2470.5, 2468.2],
      low: [2444.0, 2455.1],
      close: [2462.3, 2459.9],
      volume: [1_234_567, 987_654],
      timestamp: [1_737_974_400, 1_738_060_800]
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#daily" do
    it "POSTs camelized params to /v2/charts/historical" do
      stub_request(:post, "#{base}/historical")
        .to_return(status: 200, body: chart_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.daily(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "D")

      expect(WebMock).to(have_requested(:post, "#{base}/historical").with do |req|
        JSON.parse(req.body).values_at("securityId", "exchangeSegment", "instrument", "timeframe") ==
          %w[1333 NSE_EQ EQUITY D]
      end)
    end

    it "sends the client-id header and injects dhanClientId into the body" do
      stub_request(:post, "#{base}/historical")
        .to_return(status: 200, body: chart_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.daily(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "D")

      expect(WebMock).to(have_requested(:post, "#{base}/historical").with do |req|
        JSON.parse(req.body)["dhanClientId"] == "test_client_id"
      end)
      expect(WebMock).to have_requested(:post, "#{base}/historical")
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "returns candle arrays with indifferent access" do
      stub_request(:post, "#{base}/historical")
        .to_return(status: 200, body: chart_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.daily(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "D")

      expect(response["close"]).to eq([2462.3, 2459.9])
      expect(response[:volume]).to eq([1_234_567, 987_654])
    end

    it "raises InputExceptionError on 400" do
      stub_request(:post, "#{base}/historical").to_return(
        status: 400,
        body: { errorCode: "DH-905", errorMessage: "Input exception" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect do
        resource.daily(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "D")
      end.to raise_error(DhanHQ::InputExceptionError, /DH-905/)
    end

    it "raises InvalidTokenError when the data API reports token expiry (807)" do
      stub_request(:post, "#{base}/historical").to_return(
        status: 401,
        body: { errorCode: 807, errorMessage: "Token expired" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect do
        resource.daily(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "D")
      end.to raise_error(DhanHQ::TokenExpiredError)
    end
  end

  describe "#intraday" do
    it "POSTs camelized params to /v2/charts/intraday" do
      stub_request(:post, "#{base}/intraday")
        .to_return(status: 200, body: chart_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.intraday(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "5")

      expect(WebMock).to(have_requested(:post, "#{base}/intraday").with do |req|
        JSON.parse(req.body).values_at("securityId", "timeframe") == %w[1333 5]
      end)
    end

    it "returns minute candles with indifferent access" do
      stub_request(:post, "#{base}/intraday")
        .to_return(status: 200, body: chart_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.intraday(security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY", timeframe: "5")

      expect(response[:open]).to eq([2450.1, 2461.0])
      expect(response["timestamp"]).to eq([1_737_974_400, 1_738_060_800])
    end
  end
end
