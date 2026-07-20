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
        required(:from_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?\z/)
        required(:to_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?\z/)

        optional(:expiry_code).maybe(:integer, included_in?: ExpiryCode::ALL)
        optional(:interval).maybe(:string, included_in?: CHART_INTERVALS)
        optional(:oi).maybe(:bool)
      end

      rule(:from_date, :to_date) do
        next unless values[:from_date].match?(/\A\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?\z/) &&
                    values[:to_date].match?(/\A\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?\z/)

        from_date = DateTime.parse(values[:from_date])
        to_date = DateTime.parse(values[:to_date])
        key.failure("from_date must be before or equal to to_date") if from_date > to_date
      rescue Date::Error
        key.failure("invalid date format")
      end
    end
  end
end
