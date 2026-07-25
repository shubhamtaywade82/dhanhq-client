# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::Order do
  let(:base) { "https://api.dhan.co/v2/globalstocks/orders" }

  let(:order_payload) do
    {
      orderId: "112111182198",
      securityId: "AAPL",
      tradingSymbol: "AAPL",
      transactionType: "BUY",
      orderType: "LIMIT",
      orderStatus: "PENDING",
      quantity: 2.0,
      tradedQty: 0.0,
      price: 180.0,
      avgTradedPrice: 0.0
    }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    described_class.instance_variable_set(:@resource, nil)
  end

  after do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    described_class.instance_variable_set(:@resource, nil)
  end

  describe ".all" do
    it "maps the order book to model instances" do
      stub_request(:get, base)
        .to_return(status: 200, body: [order_payload].to_json,
                   headers: { "Content-Type" => "application/json" })

      orders = described_class.all

      expect(orders.size).to eq(1)
      expect(orders.first.security_id).to eq("AAPL")
      expect(orders.first.quantity).to eq(2.0)
    end

    it "returns an empty array for a non-array response" do
      stub_request(:get, base)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.all).to eq([])
    end
  end

  describe ".find" do
    it "builds a model from the response" do
      stub_request(:get, "#{base}/112111182198")
        .to_return(status: 200, body: order_payload.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.find("112111182198").order_id).to eq("112111182198")
    end

    it "returns nil for an empty response" do
      stub_request(:get, "#{base}/missing")
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.find("missing")).to be_nil
    end
  end

  describe ".place" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "places the order then refetches the full record" do
      stub_request(:post, base)
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base}/112111182198")
        .to_return(status: 200, body: order_payload.to_json,
                   headers: { "Content-Type" => "application/json" })

      order = described_class.place(transaction_type: "BUY", order_type: "LIMIT",
                                    security_id: "AAPL", quantity: 2.0, price: 180.0)

      expect(order).to be_a(described_class)
      expect(order.trading_symbol).to eq("AAPL")
    end

    it "returns an ErrorObject when the API does not echo an order id" do
      stub_request(:post, base)
        .to_return(status: 200, body: { orderStatus: "REJECTED" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.place(transaction_type: "BUY", order_type: "LIMIT",
                                   security_id: "AAPL", quantity: 2.0, price: 180.0))
        .to be_a(DhanHQ::ErrorObject)
    end
  end

  describe "#cancel" do
    subject(:order) { described_class.new(order_payload, skip_validation: true) }

    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "returns true when the API confirms cancellation" do
      stub_request(:delete, "#{base}/112111182198")
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "CANCELLED" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(order.cancel).to be(true)
    end

    it "returns false when the order stays pending" do
      stub_request(:delete, "#{base}/112111182198")
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "PENDING" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(order.cancel).to be(false)
    end
  end

  describe "#modify" do
    subject(:order) { described_class.new(order_payload, skip_validation: true) }

    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "carries the unchanged fields the API requires and refetches" do
      stub_request(:put, "#{base}/112111182198")
        .with(body: hash_including("transactionType" => "BUY", "orderType" => "LIMIT",
                                   "securityId" => "AAPL", "price" => 185.0))
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "MODIFIED" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      stub_request(:get, "#{base}/112111182198")
        .to_return(status: 200, body: order_payload.merge(price: 185.0).to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(order.modify(price: 185.0).price).to eq(185.0)
    end
  end

  describe "status predicates" do
    it "reports a pending order" do
      order = described_class.new(order_payload, skip_validation: true)
      expect(order).to be_pending
      expect(order).not_to be_closed
    end

    it "reports a traded order as closed" do
      order = described_class.new(order_payload.merge(orderStatus: "TRADED"), skip_validation: true)
      expect(order).to be_traded
      expect(order).to be_closed
    end

    it "detects a notional order" do
      order = described_class.new(order_payload.merge(orderType: "AMOUNT", amount: 500.0), skip_validation: true)
      expect(order).to be_notional
    end

    it "detects a fractional quantity" do
      expect(described_class.new(order_payload.merge(quantity: 0.25), skip_validation: true)).to be_fractional
      expect(described_class.new(order_payload, skip_validation: true)).not_to be_fractional
    end
  end

  describe "#child_legs" do
    it "wraps child orders in model instances" do
      order = described_class.new(
        order_payload.merge(childOrders: [{ orderId: "child-1", legName: "TARGET_LEG" }]),
        skip_validation: true
      )

      expect(order.child_legs.map(&:leg_name)).to eq(["TARGET_LEG"])
    end

    it "returns an empty array when there are no child orders" do
      expect(described_class.new(order_payload, skip_validation: true).child_legs).to eq([])
    end
  end

  describe "#to_prompt" do
    it "summarizes the order" do
      summary = described_class.new(order_payload, skip_validation: true).to_prompt

      expect(summary).to include("BUY", "AAPL", "PENDING")
    end
  end
end
