# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates Conditional Trigger (alert order) payloads for POST /v2/alerts/orders and PUT /v2/alerts/orders/{alertId}.
    # Condition: exchangeSegment (NSE_EQ|BSE_EQ|IDX_I), timeframe (required), comparisonType, operator, expDate, frequency;
    #   indicatorName/time_frame required for TECHNICAL_* comparison types.
    # Orders: transactionType, exchangeSegment, productType (CNC|INTRADAY|MARGIN|MTF), orderType, securityId, quantity, validity, price (required); discQuantity, triggerPrice optional.
    class AlertOrderContract < BaseContract
      params do
        required(:condition).hash do
          required(:security_id).filled(:string, max_size?: 20)
          required(:exchange_segment).filled(:string, included_in?: ALERT_CONDITION_SEGMENTS)
          required(:comparison_type).filled(:string, included_in?: COMPARISON_TYPES)
          required(:time_frame).filled(:string, included_in?: ALERT_TIMEFRAMES)
          required(:operator).filled(:string, included_in?: OPERATORS)
          required(:exp_date).filled(:string)
          required(:frequency).filled(:string)
          optional(:indicator_name).maybe(:string)
          optional(:comparing_value).maybe(:float)
          optional(:comparing_indicator_name).maybe(:string)
          optional(:user_note).maybe(:string)
        end
        required(:orders).array(:hash) do
          required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
          required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
          required(:product_type).filled(:string, included_in?: MARGIN_PRODUCT_TYPES)
          required(:order_type).filled(:string, included_in?: ORDER_TYPES)
          required(:security_id).filled(:string, max_size?: 20)
          required(:quantity).filled(:integer, gt?: 0)
          required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
          required(:price).filled # string or number; API expects string, coerce in serialization
          optional(:disc_quantity).maybe(:string)
          optional(:trigger_price).maybe(:string)
        end
      end

      rule(condition: :indicator_name) do
        next unless values.dig(:condition, :comparison_type).to_s.start_with?("TECHNICAL")
        next if value && !value.to_s.strip.empty?

        key([:condition, :indicator_name]).failure("is required for technical comparisons")
      end

      rule(condition: :time_frame) do
        next unless values.dig(:condition, :comparison_type).to_s.start_with?("TECHNICAL")
        next if value && !value.to_s.strip.empty?

        key([:condition, :time_frame]).failure("is required for technical comparisons")
      end
    end
  end
end
