# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for converting positions between product types.
    class PositionConversionContract < BaseContract
      params do
        required(:dhanClientId).filled(:string)
        required(:fromProductType).filled(:string, included_in?: PRODUCT_TYPES)
        required(:exchangeSegment).filled(:string, included_in?: EXCHANGE_SEGMENTS - %w[IDX_I NSE_COMM])
        required(:positionType).filled(:string, included_in?: %w[LONG SHORT CLOSED])
        required(:securityId).filled(:string)
        required(:convertQty).filled(:integer, gt?: 0)
        required(:toProductType).filled(:string, included_in?: PRODUCT_TYPES)
      end

      rule(:toProductType, :fromProductType) do
        key(:toProductType).failure("must be different from fromProductType") if values[:toProductType] == values[:fromProductType]

        if %w[BO CO].include?(values[:toProductType]) || %w[BO CO].include?(values[:fromProductType])
          key(:base).failure("cannot convert to or from Bracket (BO) or Cover (CO) orders")
        end
      end

      # Segment-Based Product Restrictions for conversion
      rule(:toProductType, :exchangeSegment) do
        case values[:toProductType]
        when DhanHQ::Constants::ProductType::CNC, DhanHQ::Constants::ProductType::MTF
          key(:toProductType).failure("is only allowed for Equity segments (NSE_EQ, BSE_EQ)") unless /_EQ$/.match?(values[:exchangeSegment])
        when DhanHQ::Constants::ProductType::MARGIN
          key(:toProductType).failure("is not allowed for Equity Cash segments; use CNC or INTRADAY") if /_EQ$/.match?(values[:exchangeSegment])
        end
      end
    end
  end
end
