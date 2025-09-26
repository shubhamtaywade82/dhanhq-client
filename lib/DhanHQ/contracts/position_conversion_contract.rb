# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for converting positions between product types.
    class PositionConversionContract < BaseContract
      params do
        required(:dhanClientId).filled(:string)
        required(:fromProductType).filled(:string, included_in?: PRODUCT_TYPES)
        required(:exchangeSegment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:positionType).filled(:string, included_in?: %w[LONG SHORT CLOSED])
        required(:securityId).filled(:string)
        required(:convertQty).filled(:integer, gt?: 0)
        required(:toProductType).filled(:string, included_in?: PRODUCT_TYPES)
      end

      rule(:toProductType, :fromProductType) do
        next unless values[:toProductType] == values[:fromProductType]

        key(:toProductType).failure("must be different from fromProductType")
      end
    end
  end
end
