# frozen_string_literal: true

require "date"

module DhanHQ
  module Contracts
    ##
    # Validation contract for trade-related operations
    class TradeContract < BaseContract
      # No input validation needed for GET requests
      # These contracts are mainly for documentation and future extensibility
    end

    ##
    # Validation contract for trade history requests
    class TradeHistoryContract < BaseContract
      params do
        required(:from_date).filled(:string)
        required(:to_date).filled(:string)
        optional(:page).filled(:integer, gteq?: 0)
      end

      rule(:from_date) do
        key.failure("must be in YYYY-MM-DD format (e.g., 2024-01-15)") unless valid_date_format?(value)
        key.failure("must be a valid trading date (no weekend dates)") if valid_date_format?(value) && !trading_day?(Date.parse(value))
      end

      rule(:to_date) do
        key.failure("must be in YYYY-MM-DD format (e.g., 2024-01-15)") unless valid_date_format?(value)
      end

      rule(:from_date, :to_date) do
        from_date_valid = valid_date_format?(values[:from_date])
        to_date_valid = valid_date_format?(values[:to_date])

        if values[:from_date] && values[:to_date] && from_date_valid && to_date_valid
          begin
            from_date = Date.parse(values[:from_date])
            to_date = Date.parse(values[:to_date])

            key.failure("from_date must be before to_date") if from_date >= to_date
          rescue Date::Error
            key.failure("invalid date format")
          end
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

      def trading_day?(date)
        return false unless date.is_a?(Date)

        (1..5).cover?(date.wday)
      end
    end

    ##
    # Validation contract for trade by order ID requests
    class TradeByOrderIdContract < BaseContract
      params do
        required(:order_id).filled(:string, min_size?: 1)
      end
    end
  end
end
