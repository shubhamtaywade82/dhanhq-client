# frozen_string_literal: true

module DhanHQ
  # Backtesting engine that replays a DhanHQ::Strategy::Base against historical
  # OHLC data and reports trades, an equity curve, and summary performance stats.
  #
  # @example Backtest a strategy against daily candles
  #   data = DhanHQ::Models::HistoricalData.daily(
  #     security_id: "1333", exchange_segment: "NSE_EQ",
  #     instrument: "EQUITY", from_date: "2024-01-01", to_date: "2024-12-31"
  #   )
  #   series = DhanHQ::MarketData::OHLCSeries.from_response(data)
  #
  #   result = DhanHQ::Backtest::Runner.new(
  #     strategy: MyStrategy.new,
  #     data: series,
  #     initial_capital: 100_000.0
  #   ).run
  #
  #   result.summary #=> { total_return_pct: 12.4, num_trades: 8, win_rate: 62.5, ... }
  #
  module Backtest
  end
end
