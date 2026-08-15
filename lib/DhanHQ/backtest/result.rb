# frozen_string_literal: true

module DhanHQ
  module Backtest
    # Aggregated outcome of a Runner run: the trade log, a per-bar equity
    # curve, and derived summary statistics. Pure math over data Runner
    # already computed — no I/O.
    class Result
      attr_reader :trades, :equity_curve, :initial_capital

      # @param trades [Array<DhanHQ::Backtest::Trade>]
      # @param equity_curve [Array<Float>] mark-to-market equity, one point per candle
      # @param initial_capital [Float]
      def initialize(trades:, equity_curve:, initial_capital:)
        @trades = trades
        @equity_curve = equity_curve
        @initial_capital = initial_capital.to_f
      end

      # @return [Float] equity after the last candle (or initial_capital if no candles ran)
      def final_equity
        equity_curve.last || initial_capital
      end

      # @return [Float] total return over the run, as a percentage of initial capital
      def total_return_pct
        return 0.0 if initial_capital.zero?

        ((final_equity - initial_capital) / initial_capital) * 100
      end

      # @return [Integer] number of completed round-trip trades
      def num_trades
        trades.size
      end

      # @return [Array<DhanHQ::Backtest::Trade>] trades that closed profitably
      def winning_trades
        trades.select(&:win?)
      end

      # @return [Float] percentage of trades that closed profitably
      def win_rate
        return 0.0 if trades.empty?

        (winning_trades.size.to_f / trades.size) * 100
      end

      # @return [Float] mean pnl across all trades
      def avg_trade_pnl
        return 0.0 if trades.empty?

        trades.sum(&:pnl) / trades.size
      end

      # @return [Float] largest peak-to-trough decline in the equity curve, as a percentage
      def max_drawdown_pct
        return 0.0 if equity_curve.empty?

        peak = equity_curve.first
        max_dd = 0.0

        equity_curve.each do |equity|
          peak = equity if equity > peak
          next if peak.zero?

          drawdown = ((peak - equity) / peak) * 100
          max_dd = drawdown if drawdown > max_dd
        end

        max_dd
      end

      # @return [Hash] rounded snapshot of the metrics above, for reporting
      def summary
        {
          total_return_pct: total_return_pct.round(2),
          num_trades: num_trades,
          win_rate: win_rate.round(2),
          avg_trade_pnl: avg_trade_pnl.round(2),
          max_drawdown_pct: max_drawdown_pct.round(2),
          final_equity: final_equity.round(2)
        }
      end
    end
  end
end
