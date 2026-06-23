# frozen_string_literal: true

require_relative "base_contract"

module DhanHQ
  module Contracts
    # Validates request for POST /v2/orders/twap (create TWAP order).
    #
    # TWAP orders slice the total quantity across the trading window at a fixed
    # interval to minimize market impact and achieve time-weighted execution.
    class TwapOrderCreateContract < BaseContract
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
        required(:slice_interval).filled(:integer, gt?: 0)
        required(:start_time).filled(:string, format?: /\A([01]?\d|2[0-3]):([0-5]?\d):([0-5]?\d)\z/)
        required(:end_time).filled(:string, format?: /\A([01]?\d|2[0-3]):([0-5]?\d):([0-5]?\d)\z/)
        optional(:correlation_id).maybe(:string, max_size?: 30, format?: /\A[a-zA-Z0-9 _-]*\z/)
        optional(:trigger_price).maybe(:float, gteq?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMINGS)
        optional(:drv_expiry_date).maybe(:string)
        optional(:drv_option_type).maybe(:string, included_in?: %w[CALL PUT NA])
        optional(:drv_strike_price).maybe(:float, gt?: 0)
      end

      rule(:start_time, :end_time) do
        next unless values[:start_time] && values[:end_time]

        start_minutes = time_to_minutes(values[:start_time])
        end_minutes = time_to_minutes(values[:end_time])
        key.failure("must be after start_time") if end_minutes <= start_minutes
      end

      rule(:slice_interval) do
        next unless value&.positive?

        start_minutes = time_to_minutes(values[:start_time])
        end_minutes = time_to_minutes(values[:end_time])
        window_minutes = end_minutes - start_minutes
        key.failure("slice interval must fit within the execution window") if value > (window_minutes * 60)
      end

      def time_to_minutes(time_str)
        parts = time_str.split(":").map(&:to_i)
        (parts[0] * 60) + parts[1]
      end
    end

    # Validates request for PUT /v2/orders/twap/{order-id} (modify TWAP order).
    class TwapOrderModifyContract < BaseContract
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
        optional(:slice_interval).maybe(:integer, gt?: 0)
        optional(:start_time).maybe(:string, format?: /\A([01]?\d|2[0-3]):([0-5]?\d):([0-5]?\d)\z/)
        optional(:end_time).maybe(:string, format?: /\A([01]?\d|2[0-3]):([0-5]?\d):([0-5]?\d)\z/)
        optional(:trigger_price).maybe(:float, gteq?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMINGS)
      end

      rule do
        modifiable_fields = %i[
          quantity price slice_interval start_time end_time
          trigger_price validity order_type product_type
        ]
        changed = modifiable_fields.any? { |field| values.key?(field) && !values[field].nil? }
        base.failure("at least one modifiable field must be provided") unless changed
      end

      rule(:order_type, :price) do
        key(:price).failure("cannot modify price for MARKET orders") if values[:order_type] == DhanHQ::Constants::OrderType::MARKET && values[:price]
      end

      rule(:start_time, :end_time) do
        next unless values[:start_time] && values[:end_time]

        start_minutes = time_to_minutes(values[:start_time])
        end_minutes = time_to_minutes(values[:end_time])
        key.failure("must be after start_time") if end_minutes <= start_minutes
      end

      def time_to_minutes(time_str)
        parts = time_str.split(":").map(&:to_i)
        (parts[0] * 60) + parts[1]
      end
    end
  end
end
