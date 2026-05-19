# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::IntradayHistoricalDataContract do
  let(:valid_intraday_params) do
    {
      security_id: "1333",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY",
      interval: "5",
      from_date: "2024-09-11",
      to_date: "2024-09-13"
    }
  end

  describe "valid intraday parameters" do
    it "passes with required interval" do
      result = described_class.new.call(valid_intraday_params)

      expect(result.success?).to be true
    end

    it "accepts all allowed intervals" do
      %w[1 5 15 25 60].each do |interval|
        result = described_class.new.call(valid_intraday_params.merge(interval: interval))
        expect(result.success?).to be true
      end
    end
  end

  describe "interval required" do
    it "fails when interval is missing" do
      params = valid_intraday_params.except(:interval)
      result = described_class.new.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:interval]).not_to be_empty
    end

    it "fails when interval is invalid" do
      result = described_class.new.call(valid_intraday_params.merge(interval: "3"))

      expect(result.failure?).to be true
      expect(result.errors[:interval]).not_to be_empty
    end
  end
end
