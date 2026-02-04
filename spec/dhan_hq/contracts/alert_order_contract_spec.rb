# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::AlertOrderContract do
  let(:contract) { described_class.new }

  let(:valid_params) do
    {
      exchange_segment: "NSE_EQ",
      security_id: "11536",
      condition: "GTE",
      trigger_price: 100.0,
      transaction_type: "BUY",
      quantity: 10
    }
  end

  describe "valid params" do
    it "accepts required fields only" do
      result = contract.call(valid_params)
      expect(result.success?).to be(true)
    end

    it "accepts optional price and order_type" do
      result = contract.call(valid_params.merge(price: 99.5, order_type: "LIMIT"))
      expect(result.success?).to be(true)
    end

    it "accepts transaction_type SELL" do
      result = contract.call(valid_params.merge(transaction_type: "SELL"))
      expect(result.success?).to be(true)
    end
  end

  describe "invalid params" do
    it "rejects missing required exchange_segment" do
      result = contract.call(valid_params.except(:exchange_segment))
      expect(result.success?).to be(false)
      expect(result.errors[:exchange_segment]).not_to be_empty
    end

    it "rejects invalid transaction_type" do
      result = contract.call(valid_params.merge(transaction_type: "INVALID"))
      expect(result.success?).to be(false)
      expect(result.errors[:transaction_type]).not_to be_empty
    end

    it "rejects quantity zero or negative" do
      result = contract.call(valid_params.merge(quantity: 0))
      expect(result.success?).to be(false)
      expect(result.errors[:quantity]).not_to be_empty
    end
  end
end
