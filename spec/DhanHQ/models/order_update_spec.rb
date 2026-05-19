# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Models::OrderUpdate do
  let(:sample_websocket_message) do
    {
      Type: "order_alert",
      Data: {
        Exchange: "NSE",
        Segment: "E",
        Source: "N",
        SecurityId: "14366",
        ClientId: "1000000001",
        ExchOrderNo: "1400000000404591",
        OrderNo: "1124091136546",
        Product: "C",
        TxnType: "B",
        OrderType: "LMT",
        Validity: "DAY",
        DiscQuantity: 1,
        DiscQtyRem: 1,
        RemainingQuantity: 1,
        Quantity: 1,
        TradedQty: 0,
        Price: 13,
        TriggerPrice: 0,
        TradedPrice: 0,
        AvgTradedPrice: 0,
        AlgoOrdNo: nil,
        OffMktFlag: "0",
        OrderDateTime: "2024-09-11 14:39:29",
        ExchOrderTime: "2024-09-11 14:39:29",
        LastUpdatedTime: "2024-09-11 14:39:29",
        MktType: "NL",
        ReasonDescription: "CONFIRMED",
        LegNo: 1,
        Instrument: "EQUITY",
        Symbol: "IDEA",
        ProductName: "CNC",
        Status: "PENDING",
        LotSize: 1,
        StrikePrice: nil,
        ExpiryDate: "0001-01-01 00:00:00",
        OptType: "XX",
        DisplayName: "Vodafone Idea",
        Isin: "INE669E01016",
        Series: "EQ",
        GoodTillDaysDate: "2024-09-11",
        RefLtp: 13.21,
        TickSize: 0.01,
        AlgoId: "0",
        Multiplier: 1,
        CorrelationId: "",
        Remarks: "Super Order"
      }
    }
  end

  describe ".from_websocket_message" do
    it "creates OrderUpdate from valid WebSocket message" do
      order_update = described_class.from_websocket_message(sample_websocket_message)

      expect(order_update).to be_a(described_class)
      expect(order_update.order_no).to eq("1124091136546")
      expect(order_update.symbol).to eq("IDEA")
      expect(order_update.status).to eq("PENDING")
    end

    it "returns nil for invalid message type" do
      invalid_message = { Type: "invalid", Data: {} }
      expect(described_class.from_websocket_message(invalid_message)).to be_nil
    end

    it "returns nil for message without data" do
      invalid_message = { Type: "order_alert" }
      expect(described_class.from_websocket_message(invalid_message)).to be_nil
    end
  end

  describe "transaction type helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies buy orders" do
      expect(order_update.buy?).to be true
      expect(order_update.sell?).to be false
    end

    it "identifies sell orders" do
      sell_message = sample_websocket_message.dup
      sell_message[:Data][:TxnType] = "S"
      sell_order = described_class.from_websocket_message(sell_message)

      expect(sell_order.sell?).to be true
      expect(sell_order.buy?).to be false
    end
  end

  describe "order type helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies limit orders" do
      expect(order_update.limit_order?).to be true
      expect(order_update.market_order?).to be false
    end

    it "identifies market orders" do
      market_message = sample_websocket_message.dup
      market_message[:Data][:OrderType] = "MKT"
      market_order = described_class.from_websocket_message(market_message)

      expect(market_order.market_order?).to be true
      expect(market_order.limit_order?).to be false
    end
  end

  describe "product type helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies CNC products" do
      expect(order_update.cnc_product?).to be true
      expect(order_update.intraday_product?).to be false
    end

    it "identifies intraday products" do
      intraday_message = sample_websocket_message.dup
      intraday_message[:Data][:Product] = "I"
      intraday_order = described_class.from_websocket_message(intraday_message)

      expect(intraday_order.intraday_product?).to be true
      expect(intraday_order.cnc_product?).to be false
    end
  end

  describe "order status helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies pending orders" do
      expect(order_update.pending?).to be true
      expect(order_update.traded?).to be false
    end

    it "identifies traded orders" do
      traded_message = sample_websocket_message.dup
      traded_message[:Data][:Status] = "TRADED"
      traded_order = described_class.from_websocket_message(traded_message)

      expect(traded_order.traded?).to be true
      expect(traded_order.pending?).to be false
    end
  end

  describe "execution state helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies not executed orders" do
      expect(order_update.not_executed?).to be true
      expect(order_update.partially_executed?).to be false
      expect(order_update.fully_executed?).to be false
    end

    it "identifies partially executed orders" do
      partial_message = sample_websocket_message.dup
      partial_message[:Data][:TradedQty] = 5
      partial_message[:Data][:Quantity] = 10
      partial_order = described_class.from_websocket_message(partial_message)

      expect(partial_order.partially_executed?).to be true
      expect(partial_order.not_executed?).to be false
      expect(partial_order.fully_executed?).to be false
    end

    it "identifies fully executed orders" do
      full_message = sample_websocket_message.dup
      full_message[:Data][:TradedQty] = 10
      full_message[:Data][:Quantity] = 10
      full_order = described_class.from_websocket_message(full_message)

      expect(full_order.fully_executed?).to be true
      expect(full_order.partially_executed?).to be false
      expect(full_order.not_executed?).to be false
    end
  end

  describe "super order helpers" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "identifies super orders" do
      expect(order_update.super_order?).to be true
    end

    it "identifies entry leg" do
      expect(order_update.entry_leg?).to be true
      expect(order_update.stop_loss_leg?).to be false
      expect(order_update.target_leg?).to be false
    end

    it "identifies stop loss leg" do
      stop_loss_message = sample_websocket_message.dup
      stop_loss_message[:Data][:LegNo] = 2
      stop_loss_order = described_class.from_websocket_message(stop_loss_message)

      expect(stop_loss_order.stop_loss_leg?).to be true
      expect(stop_loss_order.entry_leg?).to be false
      expect(stop_loss_order.target_leg?).to be false
    end

    it "identifies target leg" do
      target_message = sample_websocket_message.dup
      target_message[:Data][:LegNo] = 3
      target_order = described_class.from_websocket_message(target_message)

      expect(target_order.target_leg?).to be true
      expect(target_order.entry_leg?).to be false
      expect(target_order.stop_loss_leg?).to be false
    end
  end

  describe "calculation methods" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "calculates execution percentage" do
      percentage_message = sample_websocket_message.dup
      percentage_message[:Data][:TradedQty] = 3
      percentage_message[:Data][:Quantity] = 10
      percentage_order = described_class.from_websocket_message(percentage_message)

      expect(percentage_order.execution_percentage).to eq(30.0)
    end

    it "calculates pending quantity" do
      pending_message = sample_websocket_message.dup
      pending_message[:Data][:TradedQty] = 3
      pending_message[:Data][:Quantity] = 10
      pending_order = described_class.from_websocket_message(pending_message)

      expect(pending_order.pending_quantity).to eq(7)
    end

    it "calculates total value" do
      value_message = sample_websocket_message.dup
      value_message[:Data][:TradedQty] = 5
      value_message[:Data][:AvgTradedPrice] = 100.0
      value_order = described_class.from_websocket_message(value_message)

      expect(value_order.total_value).to eq(500.0)
    end
  end

  describe "status summary" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "provides comprehensive status summary" do
      summary = order_update.status_summary

      expect(summary).to include(
        order_no: "1124091136546",
        symbol: "IDEA",
        status: "PENDING",
        txn_type: "B",
        quantity: 1,
        traded_qty: 0,
        execution_percentage: 0.0,
        price: 13,
        avg_traded_price: 0,
        leg_no: 1,
        super_order: true
      )
    end
  end

  describe "to_hash" do
    let(:order_update) { described_class.from_websocket_message(sample_websocket_message) }

    it "converts to hash with all attributes" do
      hash = order_update.to_hash

      expect(hash).to be_a(Hash)
      expect(hash[:order_no]).to eq("1124091136546")
      expect(hash[:symbol]).to eq("IDEA")
      expect(hash[:status]).to eq("PENDING")
    end
  end
end
