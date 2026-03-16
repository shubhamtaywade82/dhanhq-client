# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::ForeverOrders do
  subject(:resource) { described_class.new }

  let(:params) do
    {
      "dhanClientId" => "1000000003",
      "correlationId" => "TRADER_abc1",
      "orderFlag" => "SINGLE",
      "transactionType" => "BUY",
      "exchangeSegment" => "NSE_EQ",
      "productType" => "CNC",
      "orderType" => "LIMIT",
      "validity" => "DAY",
      "securityId" => "1333",
      "quantity" => 5,
      "price" => 1428.0,
      "triggerPrice" => 1427.0
    }
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
  it_behaves_like "guarded mutating method", :cancel, "OID-1"

  describe "#create audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:post, %r{/v2/forever/orders}).to_return(
        status: 200,
        body: { orderId: "OID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_FOREVER_ORDER_ATTEMPT with correlation_id" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.create(params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_FOREVER_ORDER_ATTEMPT")
      expect(parsed["correlation_id"]).to eq("TRADER_abc1")
    end
  end

  describe "#update audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:put, %r{/v2/forever/orders/OID-1}).to_return(
        status: 200,
        body: { orderId: "OID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_FOREVER_ORDER_MODIFY_ATTEMPT with order_id" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.update("OID-1", params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_FOREVER_ORDER_MODIFY_ATTEMPT")
      expect(parsed["order_id"]).to eq("OID-1")
    end
  end

  describe "#cancel audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:delete, %r{/v2/forever/orders/OID-1}).to_return(
        status: 200,
        body: { orderId: "OID-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_FOREVER_ORDER_CANCEL_ATTEMPT with order_id" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.cancel("OID-1")

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_FOREVER_ORDER_CANCEL_ATTEMPT")
      expect(parsed["order_id"]).to eq("OID-1")
    end
  end
end
