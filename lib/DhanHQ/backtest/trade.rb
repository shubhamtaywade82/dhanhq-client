# frozen_string_literal: true

module DhanHQ
  module Backtest
    # A single completed long round-trip trade produced by Runner.
    #
    # `fees` is the total cost charged across both legs (entry + exit), already
    # netted into `pnl` — it is not deducted again by callers.
    Trade = Struct.new(
      :entry_time, :entry_price, :exit_time, :exit_price, :quantity, :exit_reason, :fees
    ) do
      # Net profit/loss for this trade, after fees.
      #
      # @return [Float]
      def pnl
        ((exit_price - entry_price) * quantity) - fees.to_f
      end

      # Net profit/loss as a percentage of the entry value.
      #
      # @return [Float]
      def pnl_pct
        entry_value = entry_price.to_f * quantity.to_f
        return 0.0 if entry_value.zero?

        (pnl / entry_value) * 100
      end

      # @return [Boolean] whether this trade closed profitably after fees
      def win?
        pnl.positive?
      end
    end
  end
end
