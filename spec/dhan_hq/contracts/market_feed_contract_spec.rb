# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::MarketFeedContract do
  let(:contract) { described_class.new }

  describe "validation" do
    it "is valid with correct payload" do
      payload = {
        "NSE_EQ" => [11_536, 3456],
        "NSE_FNO" => [49_081]
      }
      result = contract.call(payload)
      expect(result).to be_success
    end

    it "is valid with symbols as keys" do
      payload = {
        NSE_EQ: [11_536]
      }
      result = contract.call(payload)
      expect(result).to be_success
    end

    it "is invalid if empty" do
      result = contract.call({})
      expect(result).to be_failure
      expect(result.errors.to_h[nil]).to include("must provide at least one exchange segment and security ID")
    end

    it "is invalid with invalid exchange segment" do
      result = contract.call("INVALID_SEGMENT" => [123])
      expect(result).to be_failure
      expect(result.errors.to_h[:INVALID_SEGMENT]).to include("is not allowed")
    end

    it "is invalid if security IDs are not an array" do
      result = contract.call("NSE_EQ" => 11_536)
      expect(result).to be_failure
      expect(result.errors.to_h[:NSE_EQ]).to include("must be an array")
    end

    it "is invalid if security IDs array is empty" do
      result = contract.call("NSE_EQ" => [])
      expect(result).to be_failure
      expect(result.errors.to_h[:NSE_EQ]).to include("must not be empty")
    end

    it "is invalid if security IDs are not integers (and not coercible)" do
      result = contract.call("NSE_EQ" => ["abc"])
      expect(result).to be_failure
      expect(result.errors.to_h[:NSE_EQ][0]).to include("must be an integer")
    end
  end
end
