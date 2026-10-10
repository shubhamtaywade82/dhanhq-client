# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::ScanX do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/data" }

  before do
    # Pin credentials so requests are deterministic even when earlier specs
    # leave other DHAN_CLIENT_ID values in ENV.
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "#company_info" do
    it "posts camelized params to /v2/data/companyinfo" do
      stub_request(:post, "#{base}/companyinfo").to_return(
        status: 200, body: { data: { companyName: "Reliance Industries" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      resource.company_info(
        security_id: "1333", exchange_segment: "NSE_EQ",
        instrument: "EQUITY", metrics: %w[CO RATIOS]
      )

      expect(WebMock).to(have_requested(:post, "#{base}/companyinfo").with { |req| JSON.parse(req.body).values_at("securityId", "metrics") == ["1333", %w[CO RATIOS]] })
    end

    it "sends the client-id header" do
      stub_request(:post, "#{base}/companyinfo").to_return(
        status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" }
      )

      resource.company_info(
        security_id: "1333", exchange_segment: "NSE_EQ",
        instrument: "EQUITY", metrics: %w[CO]
      )

      expect(WebMock).to have_requested(:post, "#{base}/companyinfo")
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "raises on invalid params" do
      expect do
        resource.company_info(
          security_id: "1333", exchange_segment: "MCX_COMM",
          instrument: "EQUITY", metrics: %w[CO]
        )
      end.to raise_error(DhanHQ::ValidationError, /exchange_segment/)
    end
  end

  describe "#market_movers" do
    it "posts to /v2/data/marketmovers with expiry for derivatives" do
      stub_request(:post, "#{base}/marketmovers").to_return(
        status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" }
      )

      resource.market_movers(
        exchange_segment: "NSE_FNO", instrument: %w[OPTIDX OPTSTK],
        category: "HIGHEST_OI", expiry: "2026-10-29", limit: 10
      )

      expect(WebMock).to(have_requested(:post, "#{base}/marketmovers").with { |req| JSON.parse(req.body).values_at("instrument", "limit") == [%w[OPTIDX OPTSTK], 10] })
    end

    it "raises when expiry is missing for derivative instruments" do
      expect do
        resource.market_movers(
          exchange_segment: "NSE_FNO", instrument: %w[OPTIDX],
          category: "HIGHEST_OI", limit: 10
        )
      end.to raise_error(DhanHQ::ValidationError, /is required when instrument includes options or futures/)
    end
  end

  describe "#news_headlines" do
    it "injects dhanClientId into the payload" do
      stub_request(:post, "#{base}/newsheadline").to_return(
        status: 200, body: { data: { latestNews: [] } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      resource.news_headlines(categories: %w[ALL], limit: 10)

      expect(WebMock).to(have_requested(:post, "#{base}/newsheadline").with { |req| JSON.parse(req.body).values_at("categories", "dhanClientId") == [%w[ALL], "test_client_id"] })
    end

    it "raises when limit exceeds 50" do
      expect do
        resource.news_headlines(categories: %w[ALL], limit: 51)
      end.to raise_error(DhanHQ::ValidationError, /limit/)
    end
  end

  describe "#technical_data" do
    it "posts indicator requests to /v2/data/technical" do
      stub_request(:post, "#{base}/technical").to_return(
        status: 200,
        body: { securityId: "1333", timeframe: "D", data: { RSI: { value: 44.9, action: "Neutral" } } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      response = resource.technical_data(
        security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY",
        timeframe: "D", indicators: %w[RSI_14]
      )

      expect(response[:data][:RSI][:value]).to eq(44.9)
      expect(WebMock).to(have_requested(:post, "#{base}/technical").with { |req| JSON.parse(req.body).values_at("indicators", "timeframe") == [%w[RSI_14], "D"] })
    end

    it "raises on an unknown indicator" do
      expect do
        resource.technical_data(
          security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY",
          timeframe: "D", indicators: %w[ICHIMOKU]
        )
      end.to raise_error(DhanHQ::ValidationError, /indicators/)
    end
  end

  describe "hybrid routing" do
    it "keeps ScanX on the production host in hybrid mode" do
      hybrid_client = DhanHQ::Client.new(
        config: DhanHQ::Configuration.new(
          client_id: "1000000001", access_token: "test-token", mode: :hybrid
        )
      )

      stub_request(:post, "#{base}/technical").to_return(
        status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" }
      )

      hybrid_client.scanx.technical_data(
        security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY",
        timeframe: "D", indicators: %w[RSI_14]
      )

      expect(WebMock).to have_requested(:post, "#{base}/technical")
    end
  end
end
