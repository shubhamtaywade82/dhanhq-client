# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::OrderPreview do
  let(:valid_params) do
    {
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "INTRADAY",
      order_type: "MARKET",
      validity: "DAY",
      security_id: "2885",
      quantity: 1
    }
  end

  describe "#valid?" do
    it "returns true for valid order params with correlation_id" do
      params = valid_params.merge(correlation_id: "agent-001")
      preview = described_class.new(params)

      expect(preview).to be_valid
    end

    it "returns false when required fields are missing" do
      preview = described_class.new({ transaction_type: "BUY" })

      expect(preview).not_to be_valid
    end

    it "adds warning for missing correlation_id" do
      preview = described_class.new(valid_params)

      expect(preview.errors.join).to include("correlation_id")
    end
  end

  describe "#to_h" do
    it "returns a hash with expected keys" do
      params = valid_params.merge(correlation_id: "agent-001")
      preview = described_class.new(params)
      result = preview.to_h

      expect(result).to include(
        valid: true,
        action: "place_order",
        risk: "live_order_requires_confirmation"
      )
      expect(result[:requires]).to include("orders:write", "DHANHQ_MCP_ENABLE_WRITES", "LIVE_TRADING")
    end

    it "includes errors when invalid" do
      preview = described_class.new({})
      result = preview.to_h

      expect(result[:valid]).to be false
      expect(result[:errors]).not_to be_empty
    end

    it "includes a human-readable summary" do
      preview = described_class.new(valid_params)
      result = preview.to_h

      expect(result[:summary]).to include("BUY")
      expect(result[:summary]).to include("2885")
    end
  end
end
