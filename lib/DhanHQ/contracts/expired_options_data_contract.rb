# frozen_string_literal: true

require "dry/validation"
require "date"

module DhanHQ
  module Contracts
    ##
    # Validation contract for expired options data requests
    class ExpiredOptionsDataContract < BaseContract
      params do
        required(:exchange_segment).filled(:string)
        required(:interval).filled(:integer)
        required(:security_id).filled(:string)
        required(:instrument).filled(:string)
        required(:expiry_flag).filled(:string)
        required(:expiry_code).filled(:integer)
        required(:strike).filled(:string)
        required(:drv_option_type).filled(:string)
        required(:required_data).filled(:array)
        required(:from_date).filled(:string)
        required(:to_date).filled(:string)
      end

      rule(:exchange_segment) do
        valid_segments = %w[NSE_FNO BSE_FNO NSE_EQ BSE_EQ]
        key.failure("must be one of: #{valid_segments.join(", ")}") unless valid_segments.include?(value)
      end

      rule(:interval) do
        valid_intervals = [1, 5, 15, 25, 60]
        key.failure("must be one of: #{valid_intervals.join(", ")}") unless valid_intervals.include?(value)
      end

      rule(:instrument) do
        valid_instruments = %w[OPTIDX OPTSTK]
        key.failure("must be one of: #{valid_instruments.join(", ")}") unless valid_instruments.include?(value)
      end

      rule(:expiry_flag) do
        valid_flags = %w[WEEK MONTH]
        key.failure("must be one of: #{valid_flags.join(", ")}") unless valid_flags.include?(value)
      end

      rule(:strike) do
        unless value.match?(/\AATM(\+|-)?\d*\z/) || value == "ATM"
          key.failure("must be in format ATM, ATM+1, ATM-1, etc. " \
                      "(up to ATM+10/ATM-10 for Index Options, ATM+3/ATM-3 for others)")
        end
      end

      rule(:drv_option_type) do
        valid_types = %w[CALL PUT]
        key.failure("must be one of: #{valid_types.join(", ")}") unless valid_types.include?(value)
      end

      rule(:required_data) do
        valid_data_types = %w[open high low close iv volume strike oi spot]
        invalid_types = value - valid_data_types
        if invalid_types.any?
          key.failure("contains invalid data types: #{invalid_types.join(", ")}. " \
                      "Valid types: #{valid_data_types.join(", ")}")
        end
      end

      rule(:from_date, :to_date) do
        if valid_date_format?(values[:from_date]) && valid_date_format?(values[:to_date])
          begin
            from_date = Date.parse(values[:from_date])
            to_date = Date.parse(values[:to_date])

            key.failure("from_date must be before to_date") if from_date >= to_date

            # Check if date range is not too large (max 30 days)
            key.failure("date range cannot exceed 30 days") if (to_date - from_date).to_i > 30

            # Check if from_date is not too far in the past (max 5 years)
            five_years_ago = Date.today - (5 * 365)
            key.failure("from_date cannot be more than 5 years ago") if from_date < five_years_ago
          rescue Date::Error
            key.failure("invalid date format")
          end
        else
          key.failure("must be in YYYY-MM-DD format (e.g., 2021-08-01)")
        end
      end

      private

      def valid_date_format?(date_string)
        return false unless date_string.is_a?(String)
        return false unless date_string.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        begin
          Date.parse(date_string)
          true
        rescue Date::Error
          false
        end
      end
    end
  end
end
