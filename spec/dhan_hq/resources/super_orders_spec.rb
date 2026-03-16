# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::SuperOrders do
  subject(:resource) { described_class.new }

  let(:params) do
    { "dhanClientId" => "1000000003", "securityId" => "1333", "correlationId" => "TRADER_s1" }
  end

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
  it_behaves_like "guarded mutating method", :update, "OID-1", {}

  describe "#cancel — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError for a valid leg" do
        expect { resource.cancel("OID-1", "ENTRY_LEG") }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end

    it "raises ValidationError for an unknown leg regardless of LIVE_TRADING" do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false"))
      expect { resource.cancel("OID-1", "UNKNOWN_LEG") }
        .to raise_error(DhanHQ::ValidationError)
    end
  end

  describe "#create audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:post, %r{/v2/super/orders}).to_return(
        status: 200,
        body: { orderId: "OID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_SUPER_ORDER_ATTEMPT" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.create(params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_SUPER_ORDER_ATTEMPT")
    end
  end

  describe "#update audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:put, %r{/v2/super/orders/OID-1}).to_return(
        status: 200,
        body: { orderId: "OID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_SUPER_ORDER_MODIFY_ATTEMPT with order_id" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.update("OID-1", params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_SUPER_ORDER_MODIFY_ATTEMPT")
      expect(parsed["order_id"]).to eq("OID-1")
    end
  end
end
