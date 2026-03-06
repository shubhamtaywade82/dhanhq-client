# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates alert order payloads for create/update per dhanhq.co/docs/v2/conditional-trigger/
    # Condition requires exchange_segment, exp_date, frequency; time_frame required for TECHNICAL_* comparison types.
    class AlertOrderContract < BaseContract
      params do
        required(:condition).hash do
          required(:security_id).filled(:string, max_size?: 20)
          required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
          required(:comparison_type).filled(:string, included_in?: COMPARISON_TYPES)
          optional(:indicator_name).maybe(:string)
          optional(:time_frame).maybe(:string)
          required(:operator).filled(:string, included_in?: OPERATORS)
          optional(:comparing_value).maybe(:float)
          optional(:comparing_indicator_name).maybe(:string)
          required(:exp_date).filled(:string)
          required(:frequency).filled(:string)
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

      rule(condition: :indicator_name) do
        if values[:condition] && values[:condition][:comparison_type].to_s.start_with?("TECHNICAL") && !value
          key(condition: :indicator_name).failure("is required for technical comparisons")
        end
      end

      rule(condition: :time_frame) do
        if values[:condition] && values[:condition][:comparison_type].to_s.start_with?("TECHNICAL") && !value
          key(condition: :time_frame).failure("is required for technical comparisons")
        end
      end
    end
  end
end
