# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::OptionChainContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      underlying_scrip: 13,
      underlying_seg: "IDX_I",
      expiry: "2025-01-30"
    }
  end

  describe "valid parameters" do
    it "accepts a valid payload" do
      expect(contract.call(valid_params).success?).to be true
    end
  end

  describe "required field validation" do
    %i[underlying_scrip underlying_seg expiry].each do |field|
      it "fails when #{field} is missing" do
        result = contract.call(valid_params.reject { |k, _| k == field })
        expect(result.failure?).to be true
        expect(result.errors.to_h).to have_key(field)
      end
    end
  end

  describe "underlying_seg enum validation" do
    it "fails for an invalid segment" do
      result = contract.call(valid_params.merge(underlying_seg: "NSE_EQ"))
      expect(result.failure?).to be true
    end

    it "accepts all valid segments" do
      %w[IDX_I NSE_FNO BSE_FNO MCX_FO].each do |seg|
        result = contract.call(valid_params.merge(underlying_seg: seg))
        expect(result.success?).to be true
      end
    end
  end

  describe "expiry date rule" do
    it "fails when expiry is not in YYYY-MM-DD format" do
      result = contract.call(valid_params.merge(expiry: "30-01-2025"))
      expect(result.failure?).to be true
    end

    it "fails when expiry is an invalid date" do
      result = contract.call(valid_params.merge(expiry: "2025-13-40"))
      expect(result.failure?).to be true
    end
  end
end

RSpec.describe DhanHQ::Contracts::OptionChainExpiryListContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    { underlying_scrip: 13, underlying_seg: "IDX_I" }
  end

  describe "valid parameters" do
    it "accepts a valid payload" do
      expect(contract.call(valid_params).success?).to be true
    end
  end

  describe "required field validation" do
    it "fails when underlying_scrip is missing" do
      result = contract.call(valid_params.except(:underlying_scrip))
      expect(result.failure?).to be true
    end

    it "fails when underlying_seg is invalid" do
      result = contract.call(valid_params.merge(underlying_seg: "INVALID"))
      expect(result.failure?).to be true
    end
  end
end
