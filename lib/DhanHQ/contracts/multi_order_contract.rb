# frozen_string_literal: true

require "dry-validation"
require_relative "base_contract"

module DhanHQ
  module Contracts
    # Validation contract for POST /v2/alerts/multi/orders (basket orders).
    #
    # A multi order places up to {MAX_ORDERS} unconditional orders in a single
    # request. Each leg carries a +sequence+ that identifies it in the response.
    class MultiOrderContract < BaseContract
      # Maximum legs the API accepts in one basket.
      MAX_ORDERS = 15

      TRANSACTION_TYPES = DhanHQ::Constants::TransactionType::ALL
      EXCHANGE_SEGMENTS = DhanHQ::Constants::ExchangeSegment::ALL
      PRODUCT_TYPES     = DhanHQ::Constants::ProductType::MARGIN_CALC_ALL
      ORDER_TYPES       = DhanHQ::Constants::OrderType::ALL
      VALIDITY_TYPES    = DhanHQ::Constants::Validity::ALL
      AMO_TIMES         = DhanHQ::Constants::AmoTime::ALL

      params do
        optional(:dhan_client_id).maybe(:string)

        required(:orders).array(:hash) do
          required(:sequence).filled(:string)
          required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
          required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)

          optional(:product_type).maybe(:string, included_in?: PRODUCT_TYPES)
          optional(:order_type).maybe(:string, included_in?: ORDER_TYPES)
          optional(:validity).maybe(:string, included_in?: VALIDITY_TYPES)
          optional(:security_id).maybe(:string)
          optional(:quantity).maybe(:integer, gt?: 0)
          optional(:price).maybe(:float, gt?: 0)
          optional(:trigger_price).maybe(:float, gt?: 0)
          optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
          optional(:correlation_id).maybe(:string, max_size?: 30)
          optional(:after_market_order).maybe(:bool)
          optional(:amo_time).maybe(:string, included_in?: AMO_TIMES)
        end
      end

      rule(:orders) do
        key.failure("must contain at least one order") if value.empty?
        key.failure("cannot contain more than #{MAX_ORDERS} orders") if value.size > MAX_ORDERS

        sequences = value.map { |order| order[:sequence] }
        key.failure("sequence values must be unique") if sequences.uniq.size != sequences.size
      end

      # Order types that require a trigger price on each leg.
      TRIGGERED_ORDER_TYPES = [
        DhanHQ::Constants::OrderType::STOP_LOSS,
        DhanHQ::Constants::OrderType::STOP_LOSS_MARKET
      ].freeze

      # Per-leg price/trigger consistency, mirroring the single-order contract.
      rule(:orders) do
        value.each_with_index do |order, index|
          type = order[:order_type]

          key([:orders, index, :price]).failure("must be present for LIMIT orders") if type == DhanHQ::Constants::OrderType::LIMIT && !order[:price]
          key([:orders, index, :price]).failure("must not be provided for MARKET orders") if type == DhanHQ::Constants::OrderType::MARKET && order[:price]

          next unless TRIGGERED_ORDER_TYPES.include?(type) && !order[:trigger_price]

          key([:orders, index, :trigger_price]).failure("must be present for STOP_LOSS orders")
        end
      end
    end
  end
end
