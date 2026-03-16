# frozen_string_literal: true

# TradingGuard is exercised indirectly via the resource specs.
# This spec verifies the module in isolation using a minimal test double.
RSpec.describe DhanHQ::TradingGuard do
  subject(:guard) { host_class.new }

  let(:host_class) do
    Class.new do
      include DhanHQ::TradingGuard

      public :ensure_live_trading!, :log_order_context
    end
  end

  before do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "9.9.9.9")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::9")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "#ensure_live_trading!" do
    context "when LIVE_TRADING=true" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

      it "does not raise" do
        expect { guard.ensure_live_trading! }.not_to raise_error
      end
    end

    context "when LIVE_TRADING is absent or not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => nil)) }

      it "raises LiveTradingDisabledError" do
        expect { guard.ensure_live_trading! }
          .to raise_error(DhanHQ::LiveTradingDisabledError, /Live trading is disabled/)
      end
    end
  end

  describe "#log_order_context" do
    let(:log_lines) { [] }
    let(:parsed) { JSON.parse(log_lines.first) }

    before do
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }
      guard.log_order_context("TEST_EVENT", { "securityId" => "123", "correlationId" => "COR_1" })
    end

    it "emits exactly one WARN log line" do
      expect(log_lines.size).to eq(1)
    end

    it "logs the event name" do
      expect(parsed["event"]).to eq("TEST_EVENT")
    end

    it "logs the public IPv4" do
      expect(parsed["ipv4"]).to eq("9.9.9.9")
    end

    it "logs the security_id from camelCase params" do
      expect(parsed["security_id"]).to eq("123")
    end

    it "logs the correlation_id from camelCase params" do
      expect(parsed["correlation_id"]).to eq("COR_1")
    end

    it "logs a UTC timestamp" do
      expect(parsed["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end

    context "when called with no params" do
      before do
        log_lines.clear
        guard.log_order_context("BARE_EVENT")
      end

      it "omits nil fields from the log" do
        expect(parsed).not_to have_key("security_id")
        expect(parsed).not_to have_key("correlation_id")
        expect(parsed).not_to have_key("order_id")
      end
    end
  end
end
