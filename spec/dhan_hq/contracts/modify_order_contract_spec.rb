# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::ModifyOrderContract do
  let(:contract) { described_class.new }
  let(:valid_modify_params) do
    {
      order_id: "12345",
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "CNC",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: "1333",
      quantity: 20,
      price: 155.0
    }
  end

  it "accepts valid modification parameters" do
    expect(contract.call(valid_modify_params).success?).to be true
  end

  it "rejects modification when no modifiable fields are provided" do
    result = contract.call(order_id: "12345")
    expect(result.success?).to be false
    expect(result.errors.to_h[nil]).to include(/at least one modifiable field must be provided/)
  end

  it "enforces SL price relationship inherited from parent (BUY stop-loss)" do
    params = valid_modify_params.merge(order_type: "STOP_LOSS", trigger_price: 140.0, price: 150.0)
    result = contract.call(params)
    expect(result.success?).to be false
    expect(result.errors.to_h[:trigger_price]).to include("must be >= price for BUY stop-loss")
  end

  it "rejects price modification for MARKET orders" do
    result = contract.call(valid_modify_params.merge(order_type: "MARKET", price: 100.0))
    expect(result.success?).to be false
    expect(result.errors.to_h[:price]).to include("cannot modify price for MARKET orders")
  end

  it "rejects invalid leg_name for BO orders" do
    params = valid_modify_params.merge(product_type: "BO", leg_name: "INVALID_LEG")
    result = contract.call(params)
    expect(result.success?).to be false
    expect(result.errors.to_h[:leg_name]).to include("invalid leg_name for BO order")
  end

  it "accepts valid leg_name for BO orders" do
    params = valid_modify_params.merge(product_type: "BO", leg_name: "ENTRY_LEG",
                                       bo_profit_value: 170.0, bo_stop_loss_value: 140.0)
    expect(contract.call(params).success?).to be true
  end
end
