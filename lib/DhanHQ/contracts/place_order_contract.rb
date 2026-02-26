# frozen_string_literal: true

require_relative "order_contract"

module DhanHQ
  module Contracts
    # Validation contract for placing an order via Dhanhq's API.
    class PlaceOrderContract < OrderContract
      params do
        # Common required fields
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string, max_size?: 20)
        required(:quantity).filled(:integer, gt?: 0)

        # Optional fields
        optional(:correlation_id).maybe(:string, max_size?: 30, format?: /\A[a-zA-Z0-9 _-]*\z/)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:price).maybe(:float, gt?: 0)
        optional(:trigger_price).maybe(:float, gt?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMES)
        optional(:bo_profit_value).maybe(:float, gt?: 0)
        optional(:bo_stop_loss_value).maybe(:float, gt?: 0)

        # Derivative specific fields
        optional(:trading_symbol).maybe(:string)
        optional(:drv_expiry_date).maybe(:string)
        optional(:drv_option_type).maybe(:string, included_in?: %w[CALL PUT NA])
        optional(:drv_strike_price).maybe(:float, gt?: 0)
      end

      rule(:drv_strike_price) do
        if value.is_a?(Float) && (value.nan? || value.infinite?)
          key.failure("must be a finite number")
        end
      end
    end
  end
end
