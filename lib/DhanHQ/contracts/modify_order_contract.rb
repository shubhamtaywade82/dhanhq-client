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
      # BO LEG VALIDATION
      # --------------------------------------------------

      rule(:leg_name, :product_type) do
        if values[:product_type] == DhanHQ::Constants::ProductType::BO
          allowed = %w[ENTRY_LEG TARGET_LEG STOP_LOSS_LEG]
          key(:leg_name).failure("invalid leg_name for BO order") unless values[:leg_name] && allowed.include?(values[:leg_name])
        end
      end
    end
  end
end
