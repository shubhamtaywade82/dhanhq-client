# frozen_string_literal: true

require_relative "base_contract"

module DhanHQ
  module Contracts
    # Validates request for POST /v2/orders/iceberg (create Iceberg order).
    #
    # Iceberg orders split a large order into multiple visible legs of a fixed
    # disclosed quantity, reducing market impact.
    class IcebergOrderCreateContract < BaseContract
      params do
        required(:dhan_client_id).filled(:string)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        required(:price).filled(:float, gt?: 0)
        required(:iceberg_qty).filled(:integer, gt?: 0)
        required(:disclosed_quantity).filled(:integer, gteq?: 0)
        optional(:correlation_id).maybe(:string, max_size?: 25, format?: /\A[a-zA-Z0-9 _-]*\z/)
        optional(:trigger_price).maybe(:float, gteq?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMINGS)
        optional(:drv_expiry_date).maybe(:string)
        optional(:drv_option_type).maybe(:string, included_in?: %w[CALL PUT NA])
        optional(:drv_strike_price).maybe(:float, gt?: 0)
      end

      rule(:iceberg_qty) do
        key.failure("must not exceed total quantity") if value && values[:quantity] && value > values[:quantity]
      end
    end

    # Validates request for PUT /v2/orders/iceberg/{order-id} (modify Iceberg order).
    class IcebergOrderModifyContract < BaseContract
      params do
        required(:dhan_client_id).filled(:string)
        required(:order_id).filled(:string)

        optional(:transaction_type).maybe(:string, included_in?: TRANSACTION_TYPES)
        optional(:exchange_segment).maybe(:string, included_in?: EXCHANGE_SEGMENTS)
        optional(:product_type).maybe(:string, included_in?: PRODUCT_TYPES)
        optional(:order_type).maybe(:string, included_in?: ORDER_TYPES)
        optional(:validity).maybe(:string, included_in?: VALIDITY_TYPES)
        optional(:security_id).maybe(:string, max_size?: 20)
        optional(:quantity).maybe(:integer, gt?: 0)
        optional(:price).maybe(:float, gt?: 0)
        optional(:iceberg_qty).maybe(:integer, gt?: 0)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:trigger_price).maybe(:float, gteq?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMINGS)
      end

      rule do
        modifiable_fields = %i[
          quantity price iceberg_qty disclosed_quantity
          trigger_price validity order_type product_type
        ]
        changed = modifiable_fields.any? { |field| values.key?(field) && !values[field].nil? }
        base.failure("at least one modifiable field must be provided") unless changed
      end

      rule(:order_type, :price) do
        key(:price).failure("cannot modify price for MARKET orders") if values[:order_type] == DhanHQ::Constants::OrderType::MARKET && values[:price]
      end

      rule(:order_type, :trigger_price) do
        if %w[STOP_LOSS STOP_LOSS_MARKET].include?(values[:order_type]) && (values[:trigger_price].nil? || values[:trigger_price].to_f <= 0)
          key(:trigger_price).failure("must be present and greater than zero for STOP_LOSS orders")
        end
      end

      rule(:iceberg_qty) do
        key.failure("must not exceed total quantity") if value && values[:quantity] && value > values[:quantity]
      end
    end
  end
end
