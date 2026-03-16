# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::AlertOrders do
  subject(:resource) { described_class.new }

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "#create — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.create({}) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#create — audit log" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "logs DHAN_ALERT_ORDER_ATTEMPT" do
      stub_request(:post, %r{/v2/alerts/orders}).to_return(
        status: 200,
        body: { alertId: "ALERT-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }

      resource.create(securityId: "11536")

      parsed = JSON.parse(log_output.first)
      expect(parsed["event"]).to eq("DHAN_ALERT_ORDER_ATTEMPT")
      expect(parsed["security_id"]).to eq("11536")
    end
  end

  describe "#update — audit log" do
    it "logs DHAN_ALERT_ORDER_MODIFY_ATTEMPT" do
      stub_request(:put, %r{/v2/alerts/orders/ALERT-1}).to_return(
        status: 200,
        body: { status: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      log_output = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_output << msg }

      resource.update("ALERT-1", { triggerPrice: 200.0 })

      parsed = JSON.parse(log_output.first)
      expect(parsed["event"]).to eq("DHAN_ALERT_ORDER_MODIFY_ATTEMPT")
    end
  end
end
