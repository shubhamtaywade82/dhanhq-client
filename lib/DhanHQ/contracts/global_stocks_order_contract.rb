# frozen_string_literal: true

require "dry-validation"
require_relative "base_contract"

module DhanHQ
  module Contracts
    # Base contract shared by the Global Stocks (US equities) order contracts.
    #
    # Global Stocks orders differ from domestic orders in three ways that make the
    # domestic {OrderContract} unusable here:
    #
    # 1. There is no +exchange_segment+, +product_type+ or +validity+ field.
    # 2. +quantity+ is a float — fractional shares are supported.
    # 3. +order_type+ adds +AMOUNT+, a notional (dollar-value) order which carries
    #    an +amount+ instead of a +quantity+.
    #
    # @see https://dhanhq.co/docs/v2/ Global Stocks section
    class GlobalStocksOrderContract < BaseContract
      TRANSACTION_TYPES = DhanHQ::Constants::TransactionType::ALL
      ORDER_TYPES       = DhanHQ::Constants::GlobalStocks::OrderType::ALL
      LEG_NAMES         = DhanHQ::Constants::GlobalStocks::LegName::ALL

      # Order types that require a limit price.
      PRICED_ORDER_TYPES = [DhanHQ::Constants::GlobalStocks::OrderType::LIMIT].freeze
      # Order types that require a trigger price.
      TRIGGERED_ORDER_TYPES = [
        DhanHQ::Constants::GlobalStocks::OrderType::STOP_LOSS,
        DhanHQ::Constants::GlobalStocks::OrderType::STOP_LOSS_MARKET
      ].freeze
    end
  end
end
