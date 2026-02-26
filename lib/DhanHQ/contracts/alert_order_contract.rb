# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates alert order payloads for create/update (exchange_segment, security_id,
    # condition, trigger_price, transaction_type, quantity; optional price, order_type).
    class AlertOrderContract < BaseContract
      params do
        required(:condition).hash do
          required(:security_id).filled(:string, max_size?: 20)
          required(:comparison_type).filled(:string, included_in?: COMPARISON_TYPES)
          optional(:indicator_name).maybe(:string)
          optional(:time_frame).maybe(:string)
          required(:operator).filled(:string, included_in?: OPERATORS)
          optional(:comparing_value).maybe(:float)
          optional(:comparing_indicator_name).maybe(:string)
        end
        required(:orders).array(:hash) do
          required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
          required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
          required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
          required(:order_type).filled(:string, included_in?: ORDER_TYPES)
          required(:security_id).filled(:string, max_size?: 20)
          required(:quantity).filled(:integer, gt?: 0)
          required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
          optional(:price).maybe(:float)
          optional(:trigger_price).maybe(:float)
        end
      end

      # Conditional logic for conditions
      rule(condition: :indicator_name) do
        if values[:condition] && values[:condition][:comparison_type].to_s.start_with?("TECHNICAL") && !value
          key(condition: :indicator_name).failure("is required for technical comparisons")
        end
      end
    end
  end
end
