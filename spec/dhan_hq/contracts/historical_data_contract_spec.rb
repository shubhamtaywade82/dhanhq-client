# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::HistoricalDataContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      security_id: "1333",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY",
      from_date: "2025-01-06", # Monday
      to_date: "2025-01-10"    # Friday
    }
  end

  describe "valid parameters" do
    it "accepts a valid payload" do
      expect(contract.call(valid_params).success?).to be true
    end

    it "accepts optional interval" do
      result = contract.call(valid_params.merge(interval: "15"))
      expect(result.success?).to be true
    end

    it "accepts optional expiry_code 0" do
      result = contract.call(valid_params.merge(expiry_code: 0))
      expect(result.success?).to be true
    end
  end

  describe "required field validation" do
    %i[security_id exchange_segment instrument from_date to_date].each do |field|
      it "fails when #{field} is missing" do
        result = contract.call(valid_params.reject { |k, _| k == field })
        expect(result.failure?).to be true
        expect(result.errors.to_h).to have_key(field)
      end
    end
  end

  describe "exchange_segment enum validation" do
    it "fails for an unrecognised exchange_segment" do
      result = contract.call(valid_params.merge(exchange_segment: "INVALID"))
      expect(result.failure?).to be true
    end
  end

  describe "instrument enum validation" do
    it "fails for an unrecognised instrument" do
      result = contract.call(valid_params.merge(instrument: "UNKNOWN"))
      expect(result.failure?).to be true
    end
  end

  describe "date format validation" do
    it "fails when from_date is not YYYY-MM-DD" do
      result = contract.call(valid_params.merge(from_date: "06-01-2025"))
      expect(result.failure?).to be true
    end

    it "fails when to_date is not YYYY-MM-DD" do
      result = contract.call(valid_params.merge(to_date: "2025/01/10"))
      expect(result.failure?).to be true
    end
  end

  describe "date range rule" do
    it "fails when from_date is after to_date" do
      result = contract.call(valid_params.merge(from_date: "2025-01-10", to_date: "2025-01-06"))
      expect(result.failure?).to be true
    end

    it "fails when from_date equals to_date" do
      result = contract.call(valid_params.merge(from_date: "2025-01-06", to_date: "2025-01-06"))
      expect(result.failure?).to be true
    end
  end

  describe "trading day rule" do
    it "fails when from_date falls on a Saturday" do
      result = contract.call(valid_params.merge(from_date: "2025-01-04")) # Saturday
      expect(result.failure?).to be true
    end

    it "fails when from_date falls on a Sunday" do
      result = contract.call(valid_params.merge(from_date: "2025-01-05")) # Sunday
      expect(result.failure?).to be true
    end
  end

  describe "interval validation" do
    it "fails for an invalid interval" do
      result = contract.call(valid_params.merge(interval: "7"))
      expect(result.failure?).to be true
    end

    it "accepts all valid intervals" do
      %w[1 5 15 25 60].each do |interval|
        result = contract.call(valid_params.merge(interval: interval))
        expect(result.success?).to be true
      end
    end
  end
end
