# frozen_string_literal: true

require_relative "strategy/base"

module DhanHQ
  # Strategy framework for building and backtesting trading strategies.
  #
  # Provides a DSL for defining entry/exit rules, risk management,
  # and signal generation.
  #
  # @example Define a simple strategy
  #   class GoldenCross < DhanHQ::Strategy::Base
  #     entry_rule :golden_cross do |data, _params|
  #       sma_20 = DhanHQ::Indicators::SMA.calculate(data.closes, period: 20)
  #       sma_50 = DhanHQ::Indicators::SMA.calculate(data.closes, period: 50)
  #
  #       sma_20.last && sma_50.last &&
  #         sma_20.last > sma_50.last &&
  #         sma_20[-2] && sma_50[-2] &&
  #         sma_20[-2] <= sma_50[-2]
  #     end
  #
  #     exit_rule :death_cross do |data, _params|
  #       sma_20 = DhanHQ::Indicators::SMA.calculate(data.closes, period: 20)
  #       sma_50 = DhanHQ::Indicators::SMA.calculate(data.closes, period: 50)
  #
  #       sma_20.last && sma_50.last && sma_20.last < sma_50.last
  #     end
  #
  #     risk_rule :max_drawdown do |context, _params|
  #       context[:drawdown].abs < 0.1
  #     end
  #   end
  #
  #   strategy = GoldenCross.new
  #   signal = strategy.evaluate_entry(data)
  #
  module Strategy
  end
end
