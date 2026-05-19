# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::OrderContract do
  let(:contract) { DhanHQ::Contracts::PlaceOrderContract.new }
  let(:base_params) do
    {
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "CNC",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: "1333",
      quantity: 10,
      price: 150.0
    }
  end

  describe "Bracket Order (BO) Logic" do
    let(:bo_params) do
      base_params.merge(
        product_type: "BO",
        bo_profit_value: 160.0,
        bo_stop_loss_value: 140.0
      )
    end

    it "accepts valid BO BUY params (Profit > Price > StopLoss)" do
      expect(contract.call(bo_params).success?).to be true
    end

    it "rejects BO BUY if StopLoss >= Price" do
      result = contract.call(bo_params.merge(bo_stop_loss_value: 150.0))
      expect(result.success?).to be false
      expect(result.errors.to_h[:bo_stop_loss_value]).to include("must be less than entry price for BUY BO")
    end

    it "rejects BO BUY if Profit <= Price" do
      result = contract.call(bo_params.merge(bo_profit_value: 150.0))
      expect(result.success?).to be false
      expect(result.errors.to_h[:bo_profit_value]).to include("must be greater than entry price for BUY BO")
    end

    it "accepts valid BO SELL params (Profit < Price < StopLoss)" do
      params = bo_params.merge(transaction_type: "SELL", bo_profit_value: 140.0, bo_stop_loss_value: 160.0)
      expect(contract.call(params).success?).to be true
    end

    it "rejects BO SELL if StopLoss <= Price" do
      params = bo_params.merge(transaction_type: "SELL", bo_profit_value: 140.0, bo_stop_loss_value: 150.0)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:bo_stop_loss_value]).to include("must be greater than entry price for SELL BO")
    end
  end

  describe "STOP_LOSS Logical Relationship" do
    it "rejects BUY STOP_LOSS if trigger_price < price" do
      params = base_params.merge(order_type: "STOP_LOSS", trigger_price: 140.0, price: 150.0)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:trigger_price]).to include("must be >= price for BUY stop-loss")
    end

    it "accepts BUY STOP_LOSS if trigger_price >= price" do
      params = base_params.merge(order_type: "STOP_LOSS", trigger_price: 155.0, price: 150.0)
      expect(contract.call(params).success?).to be true
    end

    it "rejects SELL STOP_LOSS if trigger_price > price" do
      params = base_params.merge(transaction_type: "SELL", order_type: "STOP_LOSS", trigger_price: 160.0, price: 150.0)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:trigger_price]).to include("must be <= price for SELL stop-loss")
    end
  end

  describe "Segment-Based Restrictions" do
    it "rejects MARGIN for NSE_EQ" do
      result = contract.call(base_params.merge(product_type: "MARGIN", exchange_segment: "NSE_EQ"))
      expect(result.success?).to be false
    end

    it "rejects BO for NSE_CURRENCY" do
      params = base_params.merge(
        product_type: "BO",
        exchange_segment: "NSE_CURRENCY",
        bo_profit_value: 160.0,
        bo_stop_loss_value: 140.0
      )
      result = contract.call(params)
      expect(result.success?).to be false
    end
  end

  describe "Lot & Tick Size (via instrument_meta)" do
    it "rejects quantity not a multiple of lot_size" do
      contract_with_lot = DhanHQ::Contracts::PlaceOrderContract.new(instrument_meta: { lot_size: 50 })
      result = contract_with_lot.call(base_params.merge(quantity: 75))
      expect(result.success?).to be false
      expect(result.errors.to_h[:quantity]).to include("must be multiple of lot size 50")
    end

    it "rejects price not aligned with tick_size" do
      contract_with_tick = DhanHQ::Contracts::PlaceOrderContract.new(instrument_meta: { tick_size: 0.05 })
      result = contract_with_tick.call(base_params.merge(price: 150.07))
      expect(result.success?).to be false
      expect(result.errors.to_h[:price]).to include("must align with tick size 0.05")
    end
  end

  describe "Market Order Constraints" do
    it "rejects MARKET order with a price" do
      result = contract.call(base_params.merge(order_type: "MARKET"))
      expect(result.success?).to be false
      expect(result.errors.to_h[:price]).to include("must not be provided for MARKET orders")
    end
  end

  describe "Length Constraints" do
    it "rejects security_id exceeding 20 characters" do
      result = contract.call(base_params.merge(security_id: "A" * 21))
      expect(result.success?).to be false
      expect(result.errors.to_h[:security_id]).to include("size cannot be greater than 20")
    end
  end
end
