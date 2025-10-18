# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::ExpiredOptionsDataContract do
  let(:valid_params) do
    {
      exchange_segment: "NSE_FNO",
      interval: 1,
      security_id: "13",
      instrument: "OPTIDX",
      expiry_flag: "MONTH",
      expiry_code: 1,
      strike: "ATM",
      drv_option_type: "CALL",
      required_data: %w[open high low close volume],
      from_date: "2021-08-01",
      to_date: "2021-08-30"
    }
  end

  describe "valid parameters" do
    it "passes validation with valid parameters" do
      contract = described_class.new
      result = contract.call(valid_params)

      expect(result.success?).to be true
    end
  end

  describe "exchange_segment validation" do
    it "validates valid exchange segments" do
      valid_segments = %w[NSE_FNO BSE_FNO NSE_EQ BSE_EQ]

      valid_segments.each do |segment|
        params = valid_params.merge(exchange_segment: segment)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid exchange segments" do
      invalid_params = valid_params.merge(exchange_segment: "INVALID")
      contract = described_class.new
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:exchange_segment]).to include(/must be one of/)
    end
  end

  describe "interval validation" do
    it "validates valid intervals" do
      valid_intervals = [1, 5, 15, 25, 60]

      valid_intervals.each do |interval|
        params = valid_params.merge(interval: interval)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid intervals" do
      invalid_params = valid_params.merge(interval: 99)
      contract = described_class.new
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:interval]).to include(/must be one of/)
    end
  end

  describe "instrument validation" do
    it "validates valid instruments" do
      valid_instruments = %w[OPTIDX OPTSTK]

      valid_instruments.each do |instrument|
        params = valid_params.merge(instrument: instrument)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid instruments" do
      invalid_params = valid_params.merge(instrument: "INVALID")
      contract = described_class.new
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:instrument]).to include(/must be one of/)
    end
  end

  describe "expiry_flag validation" do
    it "validates valid expiry flags" do
      valid_flags = %w[WEEK MONTH]

      valid_flags.each do |flag|
        params = valid_params.merge(expiry_flag: flag)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid expiry flags" do
      invalid_params = valid_params.merge(expiry_flag: "INVALID")
      contract = described_class.new
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:expiry_flag]).to include(/must be one of/)
    end
  end

  describe "strike validation" do
    it "validates valid strike formats" do
      valid_strikes = %w[ATM ATM+1 ATM-1 ATM+5 ATM-3 ATM+10 ATM-10]

      valid_strikes.each do |strike|
        params = valid_params.merge(strike: strike)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid strike formats" do
      invalid_strikes = %w[INVALID 18000 ATM+abc ATM-xyz ATM++ ATM-- 18000+ 18000-]

      invalid_strikes.each do |strike|
        params = valid_params.merge(strike: strike)
        contract = described_class.new
        result = contract.call(params)

        expect(result.failure?).to be true
        expect(result.errors[:strike]).to include(/must be in format ATM/)
      end
    end
  end

  describe "drv_option_type validation" do
    it "validates valid option types" do
      valid_types = %w[CALL PUT]

      valid_types.each do |type|
        params = valid_params.merge(drv_option_type: type)
        contract = described_class.new
        result = contract.call(params)

        expect(result.success?).to be true
      end
    end

    it "rejects invalid option types" do
      invalid_params = valid_params.merge(drv_option_type: "INVALID")
      contract = described_class.new
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:drv_option_type]).to include(/must be one of/)
    end
  end

  describe "required_data validation" do
    it "validates valid data types" do
      valid_data_types = %w[open high low close iv volume strike oi spot]

      params = valid_params.merge(required_data: valid_data_types)
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "validates partial data types" do
      partial_data = %w[open high low close volume]

      params = valid_params.merge(required_data: partial_data)
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "rejects invalid data types" do
      invalid_data = %w[open high invalid_field]

      params = valid_params.merge(required_data: invalid_data)
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:required_data]).to include(/contains invalid data types/)
    end

    it "rejects empty required_data array" do
      params = valid_params.merge(required_data: [])
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
        expect(result.errors[:required_data]).to include(/must be filled/)
    end
  end

  describe "date validation" do
    it "validates correct date format" do
      params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-08-15")
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "rejects invalid date format" do
      invalid_formats = %w[2021/08/01 01-08-2021 2021-8-1 invalid-date]

      invalid_formats.each do |date|
        params = valid_params.merge(from_date: date)
        contract = described_class.new
        result = contract.call(params)

        expect(result.failure?).to be true
        expect(result.errors[:from_date]).to include(/must be in YYYY-MM-DD format/)
      end
    end

    it "validates date range order" do
      params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-08-15")
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "rejects when from_date is after to_date" do
      params = valid_params.merge(from_date: "2021-09-01", to_date: "2021-08-01")
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/from_date must be before to_date/)
    end

    it "rejects when from_date equals to_date" do
      params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-08-01")
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/from_date must be before to_date/)
    end

    it "validates date range length (30 days max)" do
      params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-08-30")
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "rejects date range longer than 30 days" do
      params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-09-15")
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/date range cannot exceed 30 days/)
    end

    it "validates historical date limit (5 years max)" do
      five_years_ago = (Date.today - (5 * 365)).strftime("%Y-%m-%d")
      to_date = (Date.parse(five_years_ago) + 15).strftime("%Y-%m-%d") # 15 days later
      params = valid_params.merge(from_date: five_years_ago, to_date: to_date)
      contract = described_class.new
      result = contract.call(params)

      expect(result.success?).to be true
    end

    it "rejects dates older than 5 years" do
      six_years_ago = (Date.today - (6 * 365)).strftime("%Y-%m-%d")
      to_date = (Date.parse(six_years_ago) + 15).strftime("%Y-%m-%d") # 15 days later
      params = valid_params.merge(from_date: six_years_ago, to_date: to_date)
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/from_date cannot be more than 5 years ago/)
    end
  end

  describe "required fields validation" do
    it "requires all mandatory fields" do
      required_fields = %i[
        exchange_segment interval security_id instrument
        expiry_flag expiry_code strike drv_option_type
        required_data from_date to_date
      ]

      required_fields.each do |field|
        params = valid_params.dup
        params.delete(field)

        contract = described_class.new
        result = contract.call(params)

        expect(result.failure?).to be true
        expect(result.errors[field]).to include(/is missing/)
      end
    end
  end

  describe "edge cases" do
    it "handles nil values" do
      params = valid_params.merge(exchange_segment: nil)
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:exchange_segment]).to include(/must be filled/)
    end

    it "handles empty strings" do
      params = valid_params.merge(exchange_segment: "")
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:exchange_segment]).to include(/must be filled/)
    end

    it "handles wrong data types" do
      params = valid_params.merge(interval: "not_a_number") # Should be integer
      contract = described_class.new
      result = contract.call(params)

      expect(result.failure?).to be true
      expect(result.errors[:interval]).to include(/must be an integer/)
    end
  end
end
