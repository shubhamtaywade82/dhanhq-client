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

    it "accepts all chart exchange segments" do
      DhanHQ::Constants::CHART_EXCHANGE_SEGMENTS.each do |seg|
        result = described_class.new.call(valid_params.merge(underlying_seg: seg))
        expect(result.success?).to be true
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
