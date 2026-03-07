# frozen_string_literal: true

require "date"

module DhanHQ
  module Contracts
    # Validates payloads for POST /v2/charts/historical (daily OHLC). No interval.
    class HistoricalDataContract < BaseContract
      params do
        required(:security_id).filled(:string)
        required(:exchange_segment).filled(:string, included_in?: CHART_EXCHANGE_SEGMENTS)
        required(:instrument).filled(:string, included_in?: INSTRUMENTS)
        required(:from_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}\z/)
        required(:to_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}\z/)

        optional(:expiry_code).maybe(:integer, included_in?: ExpiryCode::ALL)
        optional(:interval).maybe(:string, included_in?: CHART_INTERVALS)
      end

      rule(:from_date) do
        next unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        d = Date.parse(value)
        key.failure("must be a valid trading date (no weekend dates)") unless trading_day?(d)
      rescue Date::Error
        key.failure("invalid date format")
      end

      rule(:from_date, :to_date) do
        next unless values[:from_date].match?(/\A\d{4}-\d{2}-\d{2}\z/) && values[:to_date].match?(/\A\d{4}-\d{2}-\d{2}\z/)

        from_date = Date.parse(values[:from_date])
        to_date = Date.parse(values[:to_date])
        key.failure("from_date must be before to_date") if from_date >= to_date
      rescue Date::Error
        key.failure("invalid date format")
      end

      private

      def trading_day?(date)
        return false unless date.is_a?(Date)

        (1..5).cover?(date.wday)
      end
    end

    # Validates payloads for POST /v2/charts/intraday (minute OHLC). Requires interval.
    class IntradayHistoricalDataContract < HistoricalDataContract
      params do
        required(:interval).filled(:string, included_in?: CHART_INTERVALS)
      end
    end
  end
end
