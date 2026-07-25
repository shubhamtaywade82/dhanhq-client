# frozen_string_literal: true

require_relative "global_stocks_order_contract"

module DhanHQ
  module Contracts
    # Validation contract for POST /v2/globalstocks/orders.
    #
    # @example
    #   DhanHQ::Contracts::GlobalStocksPlaceOrderContract.new.call(
    #     transaction_type: "BUY",
    #     order_type: "LIMIT",
    #     security_id: "AAPL",
    #     quantity: 1.0,
    #     price: 180.0
    #   )
    class GlobalStocksPlaceOrderContract < GlobalStocksOrderContract
      params do
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:security_id).filled(:string, max_size?: 50)

        optional(:correlation_id).maybe(:string, max_size?: 30, format?: /\A[a-zA-Z0-9 _-]*\z/)
        optional(:quantity).maybe(:float, gt?: 0)
        optional(:price).maybe(:float, gteq?: 0)
        optional(:trigger_price).maybe(:float, gt?: 0)
        optional(:stop_loss_price).maybe(:float, gt?: 0)
        optional(:target_price).maybe(:float, gt?: 0)
        optional(:amount).maybe(:float, gt?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:dhan_client_id).maybe(:string)
      end

      # AMOUNT orders are notional: they carry `amount` instead of `quantity`.
      # Every other order type needs a quantity.
      rule(:order_type, :quantity, :amount) do
        if values[:order_type] == DhanHQ::Constants::GlobalStocks::OrderType::AMOUNT
          key(:amount).failure("must be present for AMOUNT orders") unless values[:amount]
        elsif !values[:quantity]
          key(:quantity).failure("must be present unless order_type is AMOUNT")
        end
      end

      rule(:order_type, :price) do
        price = values[:price]

        key(:price).failure("must be greater than 0 for LIMIT orders") if PRICED_ORDER_TYPES.include?(values[:order_type]) && !price&.positive?
        key(:price).failure("must be a finite number") if price.is_a?(Float) && (price.nan? || price.infinite?)
      end

      rule(:order_type, :trigger_price) do
        key(:trigger_price).failure("must be present for STOP_LOSS orders") if TRIGGERED_ORDER_TYPES.include?(values[:order_type]) && !values[:trigger_price]
      end

      # Mirrors the domestic super-order relationship checks: a BUY exits above
      # entry and stops out below it, and vice versa for a SELL.
      rule(:transaction_type, :price, :target_price, :stop_loss_price) do
        price = values[:price]
        next unless price&.positive?

        target = values[:target_price]
        stop = values[:stop_loss_price]

        case values[:transaction_type]
        when DhanHQ::Constants::TransactionType::BUY
          key(:target_price).failure("must be greater than price for BUY orders") if target && target <= price
          key(:stop_loss_price).failure("must be less than price for BUY orders") if stop && stop >= price
        when DhanHQ::Constants::TransactionType::SELL
          key(:target_price).failure("must be less than price for SELL orders") if target && target >= price
          key(:stop_loss_price).failure("must be greater than price for SELL orders") if stop && stop <= price
        end
      end
    end
  end
end
