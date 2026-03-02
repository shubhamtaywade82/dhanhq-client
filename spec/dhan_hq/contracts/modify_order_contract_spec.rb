# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::ModifyOrderContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      dhanClientId: "CLIENT123",
      orderId: "ORD001",
      quantity: 5,
      price: 1500.0
    }
  end

  describe "valid parameters" do
    it "accepts minimal valid payload (clientId + orderId + quantity)" do
      expect(contract.call(valid_params).success?).to be true
    end

    it "accepts all optional fields" do
      result = contract.call(
        valid_params.merge(
          orderType: "LIMIT",
          triggerPrice: 1490.0,
          disclosedQuantity: 0,
          validity: "DAY"
        )
      )
      expect(result.success?).to be true
    end
  end

  describe "required field validation" do
    it "fails when dhanClientId is missing" do
      result = contract.call(valid_params.except(:dhanClientId))
      expect(result.failure?).to be true
      expect(result.errors.to_h).to have_key(:dhanClientId)
    end

    it "fails when orderId is missing" do
      result = contract.call(valid_params.except(:orderId))
      expect(result.failure?).to be true
      expect(result.errors.to_h).to have_key(:orderId)
    end
  end

  describe "orderType enum validation" do
    it "fails for an invalid orderType" do
      result = contract.call(valid_params.merge(orderType: "UNKNOWN"))
      expect(result.failure?).to be true
    end

    it "accepts all valid orderTypes" do
      %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET].each do |type|
        result = contract.call(valid_params.merge(orderType: type))
        expect(result.success?).to be true
      end
    end
  end

  describe "validity enum validation" do
    it "fails for an invalid validity" do
      result = contract.call(valid_params.merge(validity: "GTC"))
      expect(result.failure?).to be true
    end
  end

  describe "quantity + price rule" do
    it "fails when both quantity and price are nil" do
      result = contract.call(dhanClientId: "CLIENT123", orderId: "ORD001")
      expect(result.failure?).to be true
    end
  end
end
