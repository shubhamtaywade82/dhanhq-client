# frozen_string_literal: true

require_relative "market_data/market_snapshot"
require_relative "market_data/ohlc_series"
require_relative "market_data/option_snapshot"

module DhanHQ
  # Higher-level abstractions for market data consumption.
  #
  # Provides typed wrappers around raw API responses for more convenient
  # market data analysis and consumption.
  #
  # @example Quick market snapshot
  #   response = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [11536])
  #   snapshot = DhanHQ::MarketData::MarketSnapshot.from_response(response)
  #   puts snapshot.ltp("NSE_EQ", "11536")
  #
  # @example Historical OHLC series
  #   response = DhanHQ::Models::HistoricalData.daily(...)
  #   series = DhanHQ::MarketData::OHLCSeries.from_response(response)
  #   puts series.average_close
  #
  module MarketData
  end
end
