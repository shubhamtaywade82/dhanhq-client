# frozen_string_literal: true

require_relative "order_contract"

module DhanHQ
  module Contracts
    # Contract for validating order modification requests
    class ModifyOrderContract < OrderContract
      params do
        required(:order_id).filled(:string)

        optional(:transaction_type).maybe(:string, included_in?: TRANSACTION_TYPES)
        optional(:exchange_segment).maybe(:string, included_in?: EXCHANGE_SEGMENTS)
        optional(:product_type).maybe(:string, included_in?: PRODUCT_TYPES)
        optional(:order_type).maybe(:string, included_in?: ORDER_TYPES)
        optional(:validity).maybe(:string, included_in?: VALIDITY_TYPES)
        optional(:security_id).maybe(:string, max_size?: 20)
        optional(:quantity).maybe(:integer, gt?: 0)

        optional(:price).maybe(:float, gt?: 0)
        optional(:trigger_price).maybe(:float, gt?: 0)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)

        optional(:bo_profit_value).maybe(:float, gt?: 0)
        optional(:bo_stop_loss_value).maybe(:float, gt?: 0)
        optional(:leg_name).maybe(:string)
      end

      # --------------------------------------------------
      # MUST MODIFY AT LEAST ONE EXECUTION FIELD
      # --------------------------------------------------

      rule do
        modifiable_fields = %i[
          quantity price trigger_price disclosed_quantity
          bo_profit_value bo_stop_loss_value
          validity order_type
        ]

        changed = modifiable_fields.any? { |field| values.key?(field) && !values[field].nil? }

        base.failure("at least one modifiable field must be provided") unless changed
      end

      # --------------------------------------------------
      # MARKET ORDER RESTRICTION
      # --------------------------------------------------

      rule(:order_type, :price) do
        key(:price).failure("cannot modify price for MARKET orders") if values[:order_type] == DhanHQ::Constants::OrderType::MARKET && values[:price]
      end

      # --------------------------------------------------
      # STOP LOSS RELATIONSHIP VALIDATION
      # --------------------------------------------------

      rule(:order_type, :transaction_type, :price, :trigger_price) do
        next unless %w[STOP_LOSS STOP_LOSS_MARKET].include?(values[:order_type])
        next unless values[:price] && values[:trigger_price]

        if values[:transaction_type] == DhanHQ::Constants::TransactionType::BUY
          key(:trigger_price).failure("must be >= price for BUY stop-loss") if values[:trigger_price] < values[:price]
        elsif values[:transaction_type] == DhanHQ::Constants::TransactionType::SELL
          key(:trigger_price).failure("must be <= price for SELL stop-loss") if values[:trigger_price] > values[:price]
        end
      end

      # --------------------------------------------------
      # BO LEG VALIDATION
      # --------------------------------------------------

      rule(:leg_name, :product_type) do
        if values[:product_type] == DhanHQ::Constants::ProductType::BO
          allowed = %w[ENTRY_LEG TARGET_LEG STOP_LOSS_LEG]
          key(:leg_name).failure("invalid leg_name for BO order") unless values[:leg_name] && allowed.include?(values[:leg_name])
        end
      end

      # --------------------------------------------------
      # BO DIRECTIONAL VALIDATION
      # --------------------------------------------------

      rule(:product_type, :transaction_type, :price, :bo_profit_value, :bo_stop_loss_value) do
        next unless values[:product_type] == DhanHQ::Constants::ProductType::BO
        next unless values[:price] && values[:bo_profit_value] && values[:bo_stop_loss_value]

        if values[:transaction_type] == DhanHQ::Constants::TransactionType::BUY
          key(:bo_stop_loss_value).failure("must be less than entry price for BUY BO") if values[:bo_stop_loss_value] >= values[:price]
          key(:bo_profit_value).failure("must be greater than entry price for BUY BO") if values[:bo_profit_value] <= values[:price]
        elsif values[:transaction_type] == DhanHQ::Constants::TransactionType::SELL
          key(:bo_stop_loss_value).failure("must be greater than entry price for SELL BO") if values[:bo_stop_loss_value] <= values[:price]
          key(:bo_profit_value).failure("must be less than entry price for SELL BO") if values[:bo_profit_value] >= values[:price]
        end
      end

      # --------------------------------------------------
      # DISCLOSED QUANTITY SAFETY
      # --------------------------------------------------

      rule(:disclosed_quantity, :quantity) do
        next unless values[:disclosed_quantity] && values[:quantity]

        key(:disclosed_quantity).failure("cannot exceed 30% of total quantity") if values[:disclosed_quantity] > (values[:quantity] * 0.3)
      end
    end
  end
end
