# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::AlertOrders do
  subject(:resource) { described_class.new }

  let(:params) { { "securityId" => "1333", "correlationId" => "SCALPER_a1" } }

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  shared_examples "guarded mutating method" do |method_name, *args|
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.public_send(method_name, *args) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  it_behaves_like "guarded mutating method", :create, {}
  it_behaves_like "guarded mutating method", :update, "AID-1", {}
  it_behaves_like "guarded mutating method", :delete, "AID-1"

  describe "#create audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:post, %r{/v2/alerts/orders}).to_return(
        status: 200,
        body: { alertId: "AID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_ALERT_ORDER_ATTEMPT" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.create(params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_ALERT_ORDER_ATTEMPT")
    end
  end

  describe "#update audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:put, %r{/v2/alerts/orders/AID-1}).to_return(
        status: 200,
        body: { status: "success" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_ALERT_ORDER_MODIFY_ATTEMPT" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.update("AID-1", { triggerPrice: 200.0 })

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_ALERT_ORDER_MODIFY_ATTEMPT")
    end
  end

  describe "#delete audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:delete, %r{/v2/alerts/orders/AID-1}).to_return(
        status: 200,
        body: { alertId: "AID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_ALERT_ORDER_DELETE_ATTEMPT with order_id" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.delete("AID-1")

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_ALERT_ORDER_DELETE_ATTEMPT")
      expect(parsed["order_id"]).to eq("AID-1")
    end
  end
end
