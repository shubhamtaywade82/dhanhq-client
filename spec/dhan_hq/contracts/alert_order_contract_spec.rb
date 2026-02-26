# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::AlertOrderContract do
  let(:contract) { described_class.new }

  let(:valid_params) do
    {
      condition: {
        security_id: "11536",
        comparison_type: "PRICE_WITH_VALUE",
        operator: "GREATER_THAN",
        comparing_value: 100.0
      },
      orders: [
        {
          transaction_type: "BUY",
          exchange_segment: "NSE_EQ",
          product_type: "INTRADAY",
          order_type: "LIMIT",
          security_id: "11536",
          quantity: 10,
          validity: "DAY"
        }
      ]
    }
  end

  describe "valid params" do
    it "accepts required fields with nested structure" do
      result = contract.call(valid_params)
      expect(result.success?).to be(true)
    end

    it "accepts technical indicators when comparison_type is TECHNICAL_WITH_VALUE" do
      params = valid_params.dup
      params[:condition] = params[:condition].merge(
        comparison_type: "TECHNICAL_WITH_VALUE",
        indicator_name: "SMA_20",
        time_frame: "DAY"
      )
      result = contract.call(params)
      expect(result.success?).to be(true)
    end
  end

  describe "invalid params" do
    it "rejects missing indicator_name for TECHNICAL comparisons" do
      params = valid_params.dup
      params[:condition] = params[:condition].merge(comparison_type: "TECHNICAL_WITH_VALUE")
      result = contract.call(params)
      expect(result.success?).to be(false)
      expect(result.errors.to_h[:condition][:indicator_name]).to include("is required for technical comparisons")
    end

    it "rejects invalid transaction_type inside orders array" do
      params = valid_params.dup
      params[:orders] = [valid_params[:orders].first.merge(transaction_type: "INVALID")]
      result = contract.call(params)
      expect(result.success?).to be(false)
      expect(result.errors.to_h[:orders][0][:transaction_type]).to include("must be one of: BUY, SELL")
    end

    it "rejects quantity zero or negative inside orders array" do
      params = valid_params.dup
      params[:orders] = [valid_params[:orders].first.merge(quantity: 0)]
      result = contract.call(params)
      expect(result.success?).to be(false)
      expect(result.errors.to_h[:orders][0][:quantity]).to include("must be greater than 0")
    end
  end
end
