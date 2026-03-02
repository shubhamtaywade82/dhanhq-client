# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::MarginCalculatorContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      dhanClientId: "CLIENT123",
      exchangeSegment: "NSE_EQ",
      transactionType: "BUY",
      quantity: 10,
      productType: "CNC",
      securityId: "1333",
      price: 1500.0
    }
  end

  describe "valid parameters" do
    it "accepts a valid payload" do
      expect(contract.call(valid_params).success?).to be true
    end

    it "accepts optional triggerPrice" do
      result = contract.call(valid_params.merge(triggerPrice: 1490.0))
      expect(result.success?).to be true
    end
  end

  describe "required field validation" do
    %i[dhanClientId exchangeSegment transactionType quantity productType securityId price].each do |field|
      it "fails when #{field} is missing" do
        result = contract.call(valid_params.reject { |k, _| k == field })
        expect(result.failure?).to be true
        expect(result.errors.to_h).to have_key(field)
      end
    end
  end

  describe "exchangeSegment enum validation" do
    it "fails for an unrecognised segment" do
      result = contract.call(valid_params.merge(exchangeSegment: "MCX_COMM"))
      expect(result.failure?).to be true
    end

    it "accepts NSE_EQ, NSE_FNO, BSE_EQ" do
      %w[NSE_EQ NSE_FNO BSE_EQ].each do |seg|
        expect(contract.call(valid_params.merge(exchangeSegment: seg)).success?).to be true
      end
    end
  end

  describe "transactionType enum validation" do
    it "fails for an invalid transactionType" do
      result = contract.call(valid_params.merge(transactionType: "HOLD"))
      expect(result.failure?).to be true
    end
  end

  describe "quantity validation" do
    it "fails when quantity is zero" do
      result = contract.call(valid_params.merge(quantity: 0))
      expect(result.failure?).to be true
    end

    it "fails when quantity is negative" do
      result = contract.call(valid_params.merge(quantity: -5))
      expect(result.failure?).to be true
    end
  end

  describe "price validation" do
    it "fails when price is zero" do
      result = contract.call(valid_params.merge(price: 0.0))
      expect(result.failure?).to be true
    end

    it "fails when price is negative" do
      result = contract.call(valid_params.merge(price: -100.0))
      expect(result.failure?).to be true
    end
  end
end
