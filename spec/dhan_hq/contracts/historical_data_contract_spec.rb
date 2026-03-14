# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::HistoricalDataContract do
  let(:valid_daily_params) do
    {
      security_id: "1333",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY",
      from_date: "2024-01-02",
      to_date: "2024-01-31"
    }
  end

  describe "valid daily parameters" do
    it "passes without interval" do
      result = described_class.new.call(valid_daily_params)

      expect(result.success?).to be true
    end

    it "passes with optional expiry_code" do
      [0, 1, 2].each do |code|
        result = described_class.new.call(valid_daily_params.merge(expiry_code: code))
        expect(result.success?).to be true
      end
    end
  end

  describe "exchange_segment validation" do
    it "accepts chart segments only" do
      %w[NSE_EQ NSE_FNO NSE_CURRENCY BSE_EQ BSE_FNO BSE_CURRENCY MCX_COMM IDX_I].each do |segment|
        result = described_class.new.call(valid_daily_params.merge(exchange_segment: segment))
        expect(result.success?).to be true
      end
    end

    it "rejects NSE_COMM" do
      result = described_class.new.call(valid_daily_params.merge(exchange_segment: "NSE_COMM"))

      expect(result.failure?).to be true
      expect(result.errors[:exchange_segment]).not_to be_empty
    end
  end
end
