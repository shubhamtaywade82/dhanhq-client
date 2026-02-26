# frozen_string_literal: true

require "dry-validation"
require_relative "base_contract"

module DhanHQ
  module Contracts
    # Base contract for validating order placements and rules
    class OrderContract < BaseContract
      TRANSACTION_TYPES = %w[BUY SELL].freeze
      EXCHANGE_SEGMENTS = %w[NSE_EQ NSE_FNO NSE_CURRENCY BSE_EQ MCX_COMM BSE_CURRENCY BSE_FNO].freeze
      PRODUCT_TYPES = %w[CNC INTRADAY MARGIN CO BO].freeze
      ORDER_TYPES = %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET].freeze
      VALIDITY_TYPES = %w[DAY IOC].freeze
      AMO_TIMES = %w[PRE_OPEN OPEN OPEN_30 OPEN_60].freeze

      params do
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)

        optional(:correlation_id).maybe(:string)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:price).maybe(:float, gt?: 0)
        optional(:trigger_price).maybe(:float, gt?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMES)
        optional(:bo_profit_value).maybe(:float, gt?: 0)
        optional(:bo_stop_loss_value).maybe(:float, gt?: 0)
        optional(:leg_name).maybe(:string)
      end

      # --------------------------------------------------
      # ORDER TYPE VALIDATION
      # --------------------------------------------------

      rule(:order_type, :price) do
        if values[:order_type] == DhanHQ::Constants::OrderType::LIMIT && !values[:price]
          key(:price).failure("must be present for LIMIT orders")
        end

        if values[:order_type] == DhanHQ::Constants::OrderType::MARKET && values[:price]
          key(:price).failure("must not be provided for MARKET orders")
        end

        if values[:price].is_a?(Float) && (values[:price].nan? || values[:price].infinite?)
          key(:price).failure("must be a finite number")
        end
      end

      rule(:order_type, :trigger_price) do
        if %w[STOP_LOSS STOP_LOSS_MARKET].include?(values[:order_type]) && !values[:trigger_price]
          key(:trigger_price).failure("must be present for STOP_LOSS orders")
        end
      end

      # --------------------------------------------------
      # STOP LOSS PRICE RELATIONSHIP
      # --------------------------------------------------

      rule(:order_type, :transaction_type, :price, :trigger_price) do
        next unless %w[STOP_LOSS STOP_LOSS_MARKET].include?(values[:order_type])
        next unless values[:price] && values[:trigger_price]

        if values[:transaction_type] == DhanHQ::Constants::TransactionType::BUY
          if values[:trigger_price] < values[:price]
            key(:trigger_price).failure("must be >= price for BUY stop-loss")
          end
        elsif values[:transaction_type] == DhanHQ::Constants::TransactionType::SELL
          if values[:trigger_price] > values[:price]
            key(:trigger_price).failure("must be <= price for SELL stop-loss")
          end
        end
      end

      # --------------------------------------------------
      # BRACKET ORDER LOGIC
      # --------------------------------------------------

      rule(:product_type, :bo_profit_value, :bo_stop_loss_value) do
        if (values[:product_type] == DhanHQ::Constants::ProductType::BO) && (!values[:bo_profit_value] || !values[:bo_stop_loss_value])
          key.failure("both bo_profit_value and bo_stop_loss_value required for BO orders")
        end
      end

      rule(:product_type, :transaction_type, :price, :bo_profit_value, :bo_stop_loss_value) do
        next unless values[:product_type] == DhanHQ::Constants::ProductType::BO
        next unless values[:price] && values[:bo_profit_value] && values[:bo_stop_loss_value]

        if values[:transaction_type] == DhanHQ::Constants::TransactionType::BUY
          if values[:bo_stop_loss_value] >= values[:price]
            key(:bo_stop_loss_value).failure("must be less than entry price for BUY BO")
          end
          if values[:bo_profit_value] <= values[:price]
            key(:bo_profit_value).failure("must be greater than entry price for BUY BO")
          end
        elsif values[:transaction_type] == DhanHQ::Constants::TransactionType::SELL
          if values[:bo_stop_loss_value] <= values[:price]
            key(:bo_stop_loss_value).failure("must be greater than entry price for SELL BO")
          end
          if values[:bo_profit_value] >= values[:price]
            key(:bo_profit_value).failure("must be less than entry price for SELL BO")
          end
        end
      end

      # --------------------------------------------------
      # DISCLOSED QUANTITY
      # --------------------------------------------------

      rule(:disclosed_quantity, :quantity) do
        next unless values[:disclosed_quantity]

        if values[:disclosed_quantity] > (values[:quantity] * 0.3)
          key(:disclosed_quantity).failure("cannot exceed 30% of total quantity")
        end
      end

      # --------------------------------------------------
      # AMO VALIDATION
      # --------------------------------------------------

      rule(:after_market_order, :amo_time) do
        if values[:after_market_order] == true && !values[:amo_time]
          key(:amo_time).failure("must be present when after_market_order is true")
        end
      end

      option :instrument_meta, optional: true

      # --------------------------------------------------
      # LOT SIZE ENFORCEMENT
      # --------------------------------------------------

      rule(:quantity) do
        next unless instrument_meta
        next unless instrument_meta[:lot_size]
        next unless instrument_meta[:lot_size].positive?

        lot = instrument_meta[:lot_size]

        if value % lot != 0
          key.failure("must be multiple of lot size #{lot}")
        end
      end

      # --------------------------------------------------
      # TICK SIZE ENFORCEMENT
      # --------------------------------------------------

      rule(:price) do
        next unless instrument_meta
        next unless instrument_meta[:tick_size]
        next unless value

        tick = instrument_meta[:tick_size]

        remainder = ((value.to_f / tick) % 1).round(10)

        if remainder != 0
          key.failure("must align with tick size #{tick}")
        end
      end

      rule(:trigger_price) do
        next unless instrument_meta
        next unless instrument_meta[:tick_size]
        next unless value

        tick = instrument_meta[:tick_size]

        remainder = ((value.to_f / tick) % 1).round(10)

        if remainder != 0
          key.failure("must align with tick size #{tick}")
        end
      end

      # --------------------------------------------------
      # SEGMENT RESTRICTIONS
      # --------------------------------------------------

      rule(:exchange_segment, :product_type) do
        next unless values[:exchange_segment] && values[:product_type]

        segment = values[:exchange_segment]
        product = values[:product_type]

        if product == DhanHQ::Constants::ProductType::CNC && !%w[NSE_EQ BSE_EQ].include?(segment)
          key(:product_type).failure("is only allowed for Equity segments")
        end

        if product == DhanHQ::Constants::ProductType::MARGIN && %w[NSE_EQ BSE_EQ].include?(segment)
          key(:product_type).failure("is not allowed for Equity Cash segments")
        end

        # BO not allowed in some segments
        if %w[NSE_CURRENCY BSE_CURRENCY].include?(segment) && product == DhanHQ::Constants::ProductType::BO
          key(:product_type).failure("BO not allowed for currency segment")
        end

        # CO restrictions example
        if segment == DhanHQ::Constants::ExchangeSegment::NSE_EQ && product == DhanHQ::Constants::ProductType::CO
          key(:product_type).failure("CO not supported in NSE_EQ")
        end
      end
    end
  end
end
