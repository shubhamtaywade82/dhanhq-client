# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::OptionChainContract do
  let(:valid_params) do
    { underlying_scrip: 13, underlying_seg: "IDX_I", expiry: "2024-10-31" }
  end

  describe "valid parameters" do
    it "passes with required fields" do
      result = described_class.new.call(valid_params)
      expect(result.success?).to be true
    end

    it "accepts only option-chain underlying segments (IDX_I, NSE_FNO, BSE_FNO, MCX_FO)" do
      DhanHQ::Constants::OPTION_CHAIN_UNDERLYING_SEGMENTS.each do |seg|
        result = described_class.new.call(valid_params.merge(underlying_seg: seg))
        expect(result.success?).to be true
      end
    end

    it "rejects non-option segments such as NSE_EQ and NSE_CURRENCY" do
      %w[NSE_EQ BSE_EQ NSE_CURRENCY BSE_CURRENCY MCX_COMM].each do |seg|
        result = described_class.new.call(valid_params.merge(underlying_seg: seg))
        expect(result.failure?).to be true
        expect(result.errors[:underlying_seg]).not_to be_empty
      end
    end
  end

  describe "expiry" do
    it "rejects invalid date format" do
      result = described_class.new.call(valid_params.merge(expiry: "31-10-2024"))
      expect(result.failure?).to be true
      expect(result.errors[:expiry]).not_to be_empty
    end

    it "rejects invalid date" do
      result = described_class.new.call(valid_params.merge(expiry: "2024-02-30"))
      expect(result.failure?).to be true
      expect(result.errors[:expiry]).not_to be_empty
    end
  end
end
