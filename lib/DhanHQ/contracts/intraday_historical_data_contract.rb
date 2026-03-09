# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates payloads for POST /v2/charts/intraday (minute OHLC). Requires interval.
    class IntradayHistoricalDataContract < HistoricalDataContract
      params do
        required(:interval).filled(:string, included_in?: CHART_INTERVALS)
      end
    end
  end
end
