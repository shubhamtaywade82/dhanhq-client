# frozen_string_literal: true

# lib/dhan_hq/contracts/order_contract.rb
require "dry-validation"

module DhanHQ
  module Contracts
    # Shared contract used to validate place and modify order payloads.
    class OrderContract < BaseContract
      # Allowed transaction directions supported by DhanHQ order APIs.
      TRANSACTION_TYPES = %w[BUY SELL].freeze
      # Supported exchange segments for order placement requests.
      EXCHANGE_SEGMENTS = %w[NSE_EQ NSE_FNO NSE_CURRENCY BSE_EQ MCX_COMM BSE_CURRENCY BSE_FNO].freeze
      # Permitted product types for order placement.
      PRODUCT_TYPES = %w[CNC INTRADAY MARGIN CO BO].freeze
      # Supported order execution types.
      ORDER_TYPES = %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET].freeze
      # Validity window options for orders.
      VALIDITY_TYPES = %w[DAY IOC].freeze
      # After-market execution windows.
      AMO_TIMES = %w[PRE_OPEN OPEN OPEN_30 OPEN_60].freeze

      params do
        # Common required fields
        required(:dhan_client_id).filled(:string)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)

        # Optional fields
        optional(:correlation_id).maybe(:string)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:price).maybe(:float)
        optional(:trigger_price).maybe(:float)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: AMO_TIMES)
        optional(:bo_profit_value).maybe(:float)
        optional(:bo_stop_loss_value).maybe(:float)
        optional(:leg_name).maybe(:string) # For modifications
      end

      # Conditional validation rules
      rule(:price) do
        key.failure("must be present for LIMIT orders") if values[:order_type] == "LIMIT" && !value
      end

      rule(:trigger_price) do
        if %w[STOP_LOSS STOP_LOSS_MARKET].include?(values[:order_type]) && !value
          key.failure("must be present for STOP_LOSS orders")
        end
      end

      rule(:amo_time) do
        key.failure("must be present for after market orders") if values[:after_market_order] == true && !value
      end

      rule(:bo_profit_value, :bo_stop_loss_value) do
        if values[:product_type] == "BO" && (!values[:bo_profit_value] || !values[:bo_stop_loss_value])
          key.failure("both profit and stop loss values required for BO orders")
        end
      end

      rule(:disclosed_quantity) do
        key.failure("cannot exceed 30% of total quantity") if value && value > (values[:quantity] * 0.3)
      end

      # Modification specific rules (when extending)
      rule(:leg_name) do
        if values[:product_type] == "BO" && !%w[ENTRY_LEG TARGET_LEG STOP_LOSS_LEG].include?(value)
          key.failure("invalid leg name for BO order")
        end
      end
    end
  end
end
