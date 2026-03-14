# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/margincalculator/multi.
    # Top-level: includePosition, includeOrder, dhanClientId, scripList.
    # Each scrip: exchangeSegment, transactionType, quantity, productType, securityId, price; triggerPrice optional.
    class MultiScripMarginCalcRequestContract < BaseContract
      params do
        optional(:dhanClientId).maybe(:string)
        optional(:includePosition).maybe(:bool)
        optional(:includeOrder).maybe(:bool)
        required(:scripList).array(:hash) do
          required(:exchangeSegment).filled(:string, included_in?: MARGIN_CALCULATOR_SEGMENTS)
          required(:transactionType).filled(:string, included_in?: TRANSACTION_TYPES)
          required(:quantity).filled(:integer, gt?: 0)
          required(:productType).filled(:string, included_in?: MARGIN_PRODUCT_TYPES)
          optional(:orderType).maybe(:string, included_in?: ORDER_TYPES)
          required(:securityId).filled(:string)
          required(:price).filled(:float, gt?: 0)
          optional(:triggerPrice).maybe(:float)
        end
      end
    end
  end
end
