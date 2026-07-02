# frozen_string_literal: true

require_relative "option_analytics/black_scholes"
require_relative "option_analytics/max_pain"

module DhanHQ
  # Option analytics calculations for derivatives trading.
  #
  # Provides Black-Scholes pricing, Greeks calculation, implied volatility,
  # and Max Pain analysis for option chain data.
  #
  # @example Calculate option price and Greeks
  #   price = DhanHQ::OptionAnalytics::BlackScholes.price(
  #     spot: 24000,
  #     strike: 24200,
  #     time_to_expiry: 0.038,
  #     risk_free_rate: 0.065,
  #     volatility: 0.15,
  #     option_type: :call
  #   )
  #
  #   greeks = DhanHQ::OptionAnalytics::BlackScholes.greeks(
  #     spot: 24000,
  #     strike: 24200,
  #     time_to_expiry: 0.038,
  #     risk_free_rate: 0.065,
  #     volatility: 0.15,
  #     option_type: :call
  #   )
  #
  # @example Calculate Max Pain
  #   max_pain = DhanHQ::OptionAnalytics::MaxPain.calculate(option_data)
  #
  module OptionAnalytics
  end
end
