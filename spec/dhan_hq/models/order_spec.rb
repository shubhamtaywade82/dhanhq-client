# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Order do
  subject(:order_model) { described_class }

  let(:order_id) { ENV.fetch("DHAN_TEST_ORDER_ID", "952502167319") }

  before { DhanHQ.configure_with_env }

  # --------------------------------------------------
  # VCR / Integration tests
  # --------------------------------------------------

  describe ".all" do
    it "retrieves all orders for the day", vcr: "models/orders/all" do
      orders = order_model.all

      expect(orders).to be_a(Array)
      expect(orders.first).to be_a(described_class)
    end
  end

  describe ".create" do
    let(:valid_order_params) do
      {
        correlationId: "correl-amo-test",
        transactionType: "BUY",
        exchangeSegment: "BSE_EQ",
        productType: "CNC",
        orderType: "MARKET",
        validity: "DAY",
        securityId: "539310",
        quantity: 5,
        afterMarketOrder: true,
        amoTime: "OPEN"
      }
    end

    it "places a new order and returns an order instance", vcr: "models/orders/create" do
      order = described_class.create(valid_order_params)

      expect(order).to be_a(described_class)
      expect(order.order_id).not_to be_nil
      expect(order.order_status).to eq("PENDING").or eq("TRANSIT").or eq("REJECTED")
    end
  end

  describe ".find" do
    it "retrieves an order by ID", vcr: "models/orders/order" do
      order = order_model.find(order_id)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq(order_id)
      expect(order.order_status).to eq("PENDING")
    end
  end

  describe "#update" do
    it "raises on TRADED order modification attempt", vcr: "models/orders/update" do
      found_order = described_class.find(order_id)
      expect(found_order).to be_a(described_class),
                             "Expected an Order, got #{found_order.inspect}"

      found_order.attributes[:trigger_price] = nil
      found_order.attributes[:bo_profit_value] = nil
      found_order.attributes[:bo_stop_loss_value] = nil
      found_order.attributes[:amo_time] = nil

      expect do
        found_order.modify({ quantity: 10, price: 3400.0, security_id: found_order.security_id })
      end.to raise_error(DhanHQ::OrderError)
    end
  end

  # --------------------------------------------------
  # Stubbed resource — collection helpers
  # --------------------------------------------------

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }

    before { allow(described_class).to receive(:resource).and_return(resource_double) }

    describe ".all" do
      it "wraps array responses" do
        allow(resource_double).to receive(:all).and_return([{ "orderId" => "OID1", "orderStatus" => "PENDING" }])

        orders = described_class.all
        expect(orders.map(&:order_id)).to eq(["OID1"])
      end

      it "returns [] for non-array response" do
        allow(resource_double).to receive(:all).and_return("unexpected")

        expect(described_class.all).to eq([])
      end
    end

    describe ".find" do
      it "unwraps array payloads" do
        allow(resource_double).to receive(:find).with("OID1").and_return([{ "orderId" => "OID1" }])

        order = described_class.find("OID1")
        expect(order.order_id).to eq("OID1")
      end
    end
  end
end
