# frozen_string_literal: true

module DhanHQ
  module Backtest
    # Replays a DhanHQ::Strategy::Base against historical OHLC candles and
    # returns a Result.
    #
    # Both entries and exits fill at the *next* candle's open, never the
    # signal candle's own price — evaluating a signal on a candle and then
    # filling somewhere inside that same candle is look-ahead bias, since the
    # fill price would have to come from before the candle closed (and so
    # before the signal could have fired live). The one exception is the end
    # of the dataset: an open position with no next candle to fill against is
    # force-closed at the last candle's close.
    #
    # Only one position is held at a time, matching DhanHQ::Strategy::Base's
    # single `@position` / entry-then-exit model — no pyramiding, no shorting.
    class Runner
      DEFAULT_QUANTITY = ->(equity, price) { price.positive? ? (equity / price).floor : 0 }
      NO_FEES = ->(_trade_value) { 0.0 }

      # @param strategy [DhanHQ::Strategy::Base]
      # @param data [DhanHQ::MarketData::OHLCSeries]
      # @param initial_capital [Float]
      # @param quantity [#call, Integer] `->(equity, price) { ... }`, or a fixed integer
      # @param fees [#call] `->(trade_value) { ... }`, charged once per leg (entry, exit)
      # @param max_bars_held [Integer, nil] force-exit a position held this many bars or longer
      def initialize(strategy:, data:, initial_capital:, quantity: DEFAULT_QUANTITY, fees: NO_FEES, max_bars_held: nil)
        @strategy = strategy
        @candles = data.respond_to?(:candles) ? data.candles : Array(data)
        @initial_capital = initial_capital.to_f
        @quantity = quantity.respond_to?(:call) ? quantity : ->(_equity, _price) { quantity }
        @fees = fees
        @max_bars_held = max_bars_held
      end

      # @return [DhanHQ::Backtest::Result]
      def run
        return Result.new(trades: [], equity_curve: [], initial_capital: @initial_capital) if @candles.empty?

        equity = @initial_capital
        equity_curve = []
        trades = []
        window_candles = []
        open_trade = nil
        entry_index = nil

        @candles.each_with_index do |candle, index|
          window_candles << candle
          window = DhanHQ::MarketData::OHLCSeries.new(window_candles)
          has_next = index < @candles.size - 1

          if open_trade && has_next
            trade = maybe_exit(open_trade, window, index, entry_index, equity, equity_curve, @candles[index + 1])

            if trade
              trades << trade
              equity += trade.pnl
              open_trade = nil
              entry_index = nil
            end
          elsif open_trade.nil? && has_next
            open_trade, entry_index = maybe_enter(window, @candles[index + 1], equity, index)
          end

          # A position opened this very iteration (via maybe_enter) isn't filled until the
          # *next* candle — mark-to-market must stay flat until index reaches entry_index,
          # or the equity curve would price the position off a fill that hasn't happened yet.
          filled = open_trade && index >= entry_index
          equity_curve << mark_to_market(equity, filled ? open_trade : nil, candle.close)
        end

        if open_trade
          last = @candles.last
          trade = close_trade(open_trade, last.timestamp, last.close, :end_of_data)
          trades << trade
          equity += trade.pnl
          equity_curve[-1] = equity
        end

        Result.new(trades: trades, equity_curve: equity_curve, initial_capital: @initial_capital)
      end

      private

      def maybe_enter(window, next_candle, equity, index)
        signal = @strategy.evaluate_entry(window)
        return [nil, nil] unless signal.buy?

        qty = @quantity.call(equity, next_candle.open)
        return [nil, nil] unless qty.positive?

        [{ entry_time: next_candle.timestamp, entry_price: next_candle.open, quantity: qty }, index + 1]
      end

      def maybe_exit(open_trade, window, index, entry_index, equity, equity_curve, next_candle)
        bars_held = index - entry_index
        forced = @max_bars_held && bars_held >= @max_bars_held
        drawdown = drawdown_pct(equity_curve, equity)
        violations = @strategy.check_risks(equity: equity, position: open_trade, drawdown: drawdown)
        signal = @strategy.evaluate_exit(window)

        return unless forced || violations.any? || signal.sell?

        reason = if forced
                   :max_bars_held
                 elsif violations.any?
                   :risk_violation
                 else
                   :signal
                 end
        close_trade(open_trade, next_candle.timestamp, next_candle.open, reason)
      end

      def close_trade(open_trade, exit_time, exit_price, reason)
        entry_value = open_trade[:entry_price] * open_trade[:quantity]
        exit_value = exit_price * open_trade[:quantity]

        Trade.new(
          entry_time: open_trade[:entry_time],
          entry_price: open_trade[:entry_price],
          exit_time: exit_time,
          exit_price: exit_price,
          quantity: open_trade[:quantity],
          exit_reason: reason,
          fees: @fees.call(entry_value) + @fees.call(exit_value)
        )
      end

      def mark_to_market(equity, open_trade, close_price)
        return equity unless open_trade

        equity + ((close_price - open_trade[:entry_price]) * open_trade[:quantity])
      end

      def drawdown_pct(equity_curve, current_equity)
        peak = (equity_curve + [current_equity]).max
        return 0.0 if peak.nil? || peak.zero?

        [((peak - current_equity) / peak) * 100, 0.0].max
      end
    end
  end
end
