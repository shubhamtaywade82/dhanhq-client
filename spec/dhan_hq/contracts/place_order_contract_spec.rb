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

  describe "conditional validations" do
    it "requires price for LIMIT orders" do
      params = valid_params.dup
      params.delete(:price)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:price]).to include("must be present for LIMIT orders")
    end

    it "validates disclosed_quantity is at most 30% of quantity" do
      params = valid_params.merge(quantity: 100, disclosed_quantity: 31)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:disclosed_quantity]).to include("cannot exceed 30% of total quantity")
    end

    it "accepts disclosed_quantity if at most 30% of quantity" do
      params = valid_params.merge(quantity: 100, disclosed_quantity: 30)
      result = contract.call(params)
      expect(result.success?).to be true
    end

    it "accepts correlation_id up to 30 characters and valid pattern" do
      params = valid_params.merge(correlation_id: "ABC_123-def 456") # 15 chars
      result = contract.call(params)
      expect(result.success?).to be true
    end

    it "rejects correlation_id exceeding 30 characters" do
      params = valid_params.merge(correlation_id: "a" * 31)
      result = contract.call(params)
      expect(result.success?).to be false
    end
  end

  describe "price validation" do
    it "rejects NaN values" do
      params = valid_params.merge(price: Float::NAN)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors.to_h[:price].any? { |e| e.to_s.match?(/finite number|greater than 0/) }).to be true
    end

    it "rejects Infinity values" do
      params = valid_params.merge(price: Float::INFINITY)
      result = contract.call(params)
      expect(result.success?).to be false
      expect(result.errors[:price]).to include(/must be a finite number/)
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
