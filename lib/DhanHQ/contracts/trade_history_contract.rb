# frozen_string_literal: true

require "date"

module DhanHQ
  module Contracts
    # Validation contract for trade history requests.
    class TradeHistoryContract < BaseContract
      params do
        required(:from_date).filled(:string)
        required(:to_date).filled(:string)
        optional(:page).filled(:integer, gteq?: 0)
      end

      rule(:from_date) do
        key.failure("must be in YYYY-MM-DD format (e.g., 2024-01-15)") unless valid_date_format?(value)
        next unless valid_date_format?(value)

        key.failure("must be a valid trading date (no weekend dates)") unless trading_day?(Date.parse(value))
      end

      rule(:to_date) do
        key.failure("must be in YYYY-MM-DD format (e.g., 2024-01-15)") unless valid_date_format?(value)
      end

      rule(:from_date, :to_date) do
        from = values[:from_date]
        to = values[:to_date]
        next unless valid_date_format?(from) && valid_date_format?(to)

        key.failure("from_date must be before to_date") if Date.parse(from) >= Date.parse(to)
      rescue Date::Error
        key.failure("invalid date format")
      end

      private

      def valid_date_format?(date_string)
        return false unless date_string.is_a?(String) && date_string.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.parse(date_string)
        true
      rescue Date::Error
        false
      end

      def trading_day?(date)
        date.is_a?(Date) && (1..5).cover?(date.wday)
      end
    end
  end
end

