# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  let(:live_url) { "https://api.dhan.co/v2" }
  let(:sandbox_url) { "https://sandbox.dhan.co/v2" }
  let(:config) do
    DhanHQ::Configuration.new(client_id: "1000000001", access_token: "test-token", mode: mode)
  end

  let(:place_params) do
    {
      "dhanClientId" => "1000000001", "transactionType" => "BUY", "exchangeSegment" => "NSE_EQ",
      "productType" => "INTRADAY", "orderType" => "MARKET", "validity" => "DAY",
      "securityId" => "11536", "quantity" => 5
    }
  end

  before do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    # Stub instrument lookup so order risk checks don't trigger WebMock errors
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
    ENV.delete("LIVE_TRADING")
  end

  after do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    ENV.delete("LIVE_TRADING")
  end

  describe "#environment" do
    let(:mode) { :hybrid }

    it "exposes the effective environment for the client's API tier" do
      expect(described_class.new(config: config, api_type: :order_api).environment).to eq(:sandbox)
      expect(described_class.new(config: config, api_type: :data_api).environment).to eq(:live)
    end
  end

  describe "hybrid routing" do
    let(:mode) { :hybrid }

    it "routes order posts to the sandbox host and market data to production" do
      client = described_class.new(config: config)

      stub_request(:post, "#{sandbox_url}/orders").to_return(
        status: 200, body: { orderId: "sbx-1", orderStatus: "PENDING" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request(:post, "#{live_url}/marketfeed/ltp").to_return(
        status: 200, body: { status: "success", data: {} }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      ENV["LIVE_TRADING"] = "true"
      client.orders.create(place_params)
      client.market_feed.ltp("NSE_EQ" => [11_536])

      expect(WebMock).to have_requested(:post, "#{sandbox_url}/orders")
      expect(WebMock).to have_requested(:post, "#{live_url}/marketfeed/ltp")
    end

    it "rebuilds the connection when the mode changes mid-flight" do
      client = described_class.new(config: config, api_type: :order_api)

      expect(client.connection.url_prefix.to_s).to eq(sandbox_url)

      config.mode = :live
      expect(client.connection.url_prefix.to_s).to eq(live_url)
    end
  end

  describe "per-client mode" do
    let(:mode) { :live }

    it "forks the config so a shared configuration is never mutated" do
      shared = DhanHQ::Configuration.new(client_id: "1", access_token: "t", mode: :live)
      client = described_class.new(config: shared, mode: :hybrid, api_type: :order_api)

      expect(client.config.mode).to eq(:hybrid)
      expect(client.config).not_to be(shared)
      expect(shared.mode).to eq(:live)
    end

    it "builds an isolated config from keyword attrs alone" do
      client = described_class.new(mode: :hybrid, api_type: :order_api)

      expect(client.config.mode).to eq(:hybrid)
      expect(client.environment).to eq(:sandbox)
    end
  end

  describe "LIVE_TRADING gate" do
    it "is relaxed for order posts routed to the sandbox host" do
      client = mode_client(:hybrid)

      stub_request(:post, "#{sandbox_url}/orders").to_return(
        status: 200, body: { orderId: "sbx-1", orderStatus: "PENDING" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { client.orders.create(place_params) }.not_to raise_error
      expect(WebMock).to have_requested(:post, "#{sandbox_url}/orders")
    end

    it "still blocks order posts routed to production without LIVE_TRADING" do
      client = mode_client(:live)

      expect { client.orders.create(place_params) }
        .to raise_error(DhanHQ::LiveTradingDisabledError, /sandbox/)
    end

    it "still blocks order posts in hybrid when the order tier is overridden to live" do
      client = mode_client(:hybrid)
      client.config.environment_overrides = { order_api: :live }

      expect { client.orders.create(place_params) }
        .to raise_error(DhanHQ::LiveTradingDisabledError)
    end

    it "logs the target host in the order audit trail" do
      logger = instance_double(Logger, warn: true, error: true, info: true, debug: true)
      allow(DhanHQ).to receive(:logger).and_return(logger)

      client = mode_client(:hybrid)
      stub_request(:post, "#{sandbox_url}/orders").to_return(
        status: 200, body: { orderId: "sbx-1", orderStatus: "PENDING" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      client.orders.create(place_params)

      expect(logger).to have_received(:warn).with(/"target":"sandbox"/)
    end

    def mode_client(mode)
      described_class.new(
        config: DhanHQ::Configuration.new(client_id: "1000000001", access_token: "test-token", mode: mode)
      )
    end
  end
end
