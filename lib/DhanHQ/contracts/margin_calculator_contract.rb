# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/margincalculator (single order).
    # dhanClientId, exchangeSegment (NSE_EQ|NSE_FNO|BSE_EQ|BSE_FNO|MCX_COMM), transactionType, quantity,
    # productType (CNC|INTRADAY|MARGIN|MTF), securityId, price (required); triggerPrice (optional, for SL-M/SL-L).
    class MarginCalculatorContract < BaseContract
      params do
        required(:dhanClientId).filled(:string)
        required(:exchangeSegment).filled(:string, included_in?: MARGIN_CALCULATOR_SEGMENTS)
        required(:transactionType).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:quantity).filled(:integer, gt?: 0)
        required(:productType).filled(:string, included_in?: MARGIN_PRODUCT_TYPES)
        required(:securityId).filled(:string)
        required(:price).filled(:float, gt?: 0)
        optional(:triggerPrice).maybe(:float)
      end

      rule(:price) do
        next unless values[:price].is_a?(Float)

        key.failure("must be a finite number") if values[:price].nan? || values[:price].infinite?
      end

      rule(:triggerPrice) do
        next unless values[:triggerPrice].is_a?(Float)

        key.failure("must be a finite number") if values[:triggerPrice].nan? || values[:triggerPrice].infinite?
      end

      rule(:productType, :exchangeSegment) do
        case values[:productType]
        when DhanHQ::Constants::ProductType::CNC, DhanHQ::Constants::ProductType::MTF
          key.failure("is only allowed for Equity segments (NSE_EQ, BSE_EQ)") unless values[:exchangeSegment].to_s.end_with?("_EQ")
        when DhanHQ::Constants::ProductType::MARGIN
          key.failure("is not allowed for Equity Cash segments; use CNC or INTRADAY") if values[:exchangeSegment].to_s.end_with?("_EQ")
        end
      end
    end
  end
end
