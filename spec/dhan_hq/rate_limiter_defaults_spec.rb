# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::RateLimiter do
  describe ".limits_for_config" do
    it "uses the previous-release table when enforcement is off" do
      DhanHQ.configuration.enforce_rate_limits = false
      expect(described_class.limits_for_config).to equal(described_class::LEGACY_RATE_LIMITS)
    end

    it "uses the documented table when enforcement is on" do
      DhanHQ.configuration.enforce_rate_limits = true
      expect(described_class.limits_for_config).to equal(described_class::RATE_LIMITS)
    end

    it "keeps the previous-release order caps (no per-minute or per-hour cap)" do
      expect(described_class::LEGACY_RATE_LIMITS[:order_api][:per_minute]).to eq(Float::INFINITY)
      expect(described_class::LEGACY_RATE_LIMITS[:order_api][:per_hour]).to eq(Float::INFINITY)
      expect(described_class::LEGACY_RATE_LIMITS[:order_api][:per_day]).to eq(100_000)
    end
  end
end
