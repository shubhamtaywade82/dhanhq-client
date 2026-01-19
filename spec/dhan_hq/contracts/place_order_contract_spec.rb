# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::PlaceOrderContract do
  let(:contract) { described_class.new }
  let(:valid_params) do
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

  describe "price validation" do
    it "rejects NaN values" do
      params = valid_params.merge(price: Float::NAN)
      result = contract.call(params)
      expect(result.success?).to be false
      # NaN fails gt?: 0 validation first, but rule should also catch it
      # Check that either error message is present
      price_errors = result.errors[:price] || []
      expect(price_errors.any? { |e| e.to_s.match?(/finite number|greater than 0/) }).to be true
    end

    it "rejects Infinity values" do
      params = valid_params.merge(price: Float::INFINITY)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors[:price]).to include(/must be a finite number/)
    end

    it "rejects extremely large values" do
      params = valid_params.merge(price: 2_000_000_000)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors[:price]).to include(/must be less than/)
    end

    it "accepts valid finite prices" do
      params = valid_params.merge(price: 150.50)
      result = contract.call(params)
      expect(result.success?).to be true
    end

    it "validates trigger_price for NaN/Infinity" do
      params = valid_params.merge(order_type: "STOP_LOSS", trigger_price: Float::NAN)
      result = contract.call(params)
      expect(result.success?).to be false
      # NaN fails gt?: 0 validation first, but rule should also catch it
      # Check that either error message is present
      trigger_errors = result.errors[:trigger_price] || []
      expect(trigger_errors.any? { |e| e.to_s.match?(/finite number|greater than 0/) }).to be true
    end

    it "validates bo_profit_value for NaN/Infinity" do
      params = valid_params.merge(product_type: "BO", bo_profit_value: Float::INFINITY, bo_stop_loss_value: 100.0)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors[:bo_profit_value]).to include(/must be a finite number/)
    end
  end

  describe "basic validation" do
    it "validates required fields" do
      result = contract.call({})
      expect(result.success?).to be false
      error_keys = result.errors.to_h.keys
      expect(error_keys).to include(:transaction_type, :exchange_segment, :product_type, :order_type, :validity,
                                    :security_id, :quantity)
    end

    it "accepts valid order parameters" do
      result = contract.call(valid_params)
      expect(result.success?).to be true
    end
  end
end
