# frozen_string_literal: true

RSpec.describe DhanHQ::Concerns::OrderAudit do
  let(:test_class) do
    Class.new do
      include DhanHQ::Concerns::OrderAudit

      # Expose private methods for testing
      public :ensure_live_trading!, :log_order_context, :extract_param
    end
  end

  let(:instance) { test_class.new }

  before do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "10.0.0.1")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "fe80::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "#ensure_live_trading!" do
    context "when LIVE_TRADING is 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

      it "does not raise" do
        expect { instance.ensure_live_trading! }.not_to raise_error
      end
    end

    context "when LIVE_TRADING is 'false'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { instance.ensure_live_trading! }.to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end

    context "when LIVE_TRADING is absent" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => nil)) }

      it "raises LiveTradingDisabledError" do
        expect { instance.ensure_live_trading! }.to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#log_order_context" do
    let(:audit_log) do
      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }
      instance.log_order_context("TEST_EVENT", securityId: "99", correlationId: "COR-1")
      JSON.parse(log_output.first)
    end

    it "logs the event name" do
      expect(audit_log["event"]).to eq("TEST_EVENT")
    end

    it "logs the public IPv4 and IPv6" do
      expect(audit_log["ipv4"]).to eq("10.0.0.1")
      expect(audit_log["ipv6"]).to eq("fe80::1")
    end

    it "logs security_id and correlation_id from params" do
      expect(audit_log["security_id"]).to eq("99")
      expect(audit_log["correlation_id"]).to eq("COR-1")
    end

    it "logs a UTC timestamp" do
      expect(audit_log["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end

    it "omits nil fields via compact" do
      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }

      instance.log_order_context("BARE_EVENT", {})

      parsed = JSON.parse(log_output.first)
      expect(parsed).not_to have_key("security_id")
      expect(parsed).not_to have_key("correlation_id")
      expect(parsed).not_to have_key("order_id")
    end
  end

  describe "#extract_param" do
    it "finds symbol camelCase key" do
      expect(instance.extract_param({ securityId: "1" }, :securityId, :security_id)).to eq("1")
    end

    it "finds string camelCase key" do
      expect(instance.extract_param({ "securityId" => "2" }, :securityId, :security_id)).to eq("2")
    end

    it "finds symbol snake_case key" do
      expect(instance.extract_param({ security_id: "3" }, :securityId, :security_id)).to eq("3")
    end

    it "finds string snake_case key" do
      expect(instance.extract_param({ "security_id" => "4" }, :securityId, :security_id)).to eq("4")
    end

    it "returns nil when key is absent" do
      expect(instance.extract_param({}, :securityId, :security_id)).to be_nil
    end
  end
end
