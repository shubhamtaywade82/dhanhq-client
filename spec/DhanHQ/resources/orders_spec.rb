# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Orders do
  subject(:resource) { described_class.new }

  let(:valid_place_params) do
    {
      "dhanClientId" => "1000000003",
      "correlationId" => "SCALPER_7af1",
      "transactionType" => "BUY",
      "exchangeSegment" => "NSE_EQ",
      "productType" => "INTRADAY",
      "orderType" => "MARKET",
      "validity" => "DAY",
      "securityId" => "11536",
      "quantity" => 5
    }
  end

  let(:valid_modify_params) do
    {
      "dhanClientId" => "1000000003",
      "orderId" => "ORDER123",
      "orderType" => "LIMIT",
      "quantity" => 10,
      "price" => 1500.0,
      "validity" => "DAY"
    }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!

    # Stub IP lookups so tests never hit real network
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  # ------------------------------------------------------------------
  # Live Trading Guard
  # ------------------------------------------------------------------

  describe "#create — live trading guard" do
    context "when LIVE_TRADING is not set to 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError before touching the API" do
        expect { resource.create(valid_place_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError, /Live trading is disabled/)
      end
    end

    context "when LIVE_TRADING is absent" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => nil)) }

      it "raises LiveTradingDisabledError" do
        expect { resource.create(valid_place_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#update — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.update("ORDER123", valid_modify_params.except("orderId")) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#cancel — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.cancel("ORDER123") }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#slicing — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.slicing(valid_place_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  # ------------------------------------------------------------------
  # Audit Logging
  # ------------------------------------------------------------------

  describe "#create — order audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:post, %r{/v2/orders}).to_return(
        status: 200,
        body: { status: "success", orderId: "ORD001" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    let(:audit_log) do
      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }
      resource.create(valid_place_params)
      JSON.parse(log_output.first)
    end

    it "emits at least one WARN log entry" do
      expect(audit_log["event"]).not_to be_nil
    end

    it "logs event DHAN_ORDER_ATTEMPT" do
      expect(audit_log["event"]).to eq("DHAN_ORDER_ATTEMPT")
    end

    it "logs the security_id" do
      expect(audit_log["security_id"]).to eq("11536")
    end

    it "logs the correlation_id" do
      expect(audit_log["correlation_id"]).to eq("SCALPER_7af1")
    end

    it "logs the public IPv4" do
      expect(audit_log["ipv4"]).to eq("1.2.3.4")
    end

    it "logs a UTC timestamp" do
      expect(audit_log["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end
  end

  describe "#update — order audit log" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "logs a DHAN_ORDER_MODIFY_ATTEMPT JSON line at WARN level" do
      stub_request(:put, %r{/v2/orders/ORDER123}).to_return(
        status: 200,
        body: { status: "success", orderId: "ORDER123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }

      resource.update("ORDER123", valid_modify_params.except("orderId"))

      expect(log_output.size).to be >= 1
      parsed = JSON.parse(log_output.first)
      expect(parsed["event"]).to eq("DHAN_ORDER_MODIFY_ATTEMPT")
      expect(parsed["order_id"]).to eq("ORDER123")
    end
  end

  describe "#slicing — order audit log" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "logs a DHAN_ORDER_SLICING_ATTEMPT JSON line at WARN level" do
      stub_request(:post, %r{/v2/orders/slicing}).to_return(
        status: 200,
        body: { status: "success", orderId: "ORD_SLICE" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }

      resource.slicing(valid_place_params)

      expect(log_output.size).to be >= 1
      parsed = JSON.parse(log_output.first)
      expect(parsed["event"]).to eq("DHAN_ORDER_SLICING_ATTEMPT")
    end
  end
end
