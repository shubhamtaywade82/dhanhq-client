# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for multi-scrip margin calculations.
    class MultiScripMarginCalcRequestContract < BaseContract
      params do
        optional(:dhanClientId).maybe(:string)
        optional(:includePosition).maybe(:bool)
        optional(:includeOrder).maybe(:bool)
        required(:scripList).array(:hash) do
          required(:exchangeSegment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
          required(:transactionType).filled(:string, included_in?: TRANSACTION_TYPES)
          required(:quantity).filled(:integer, gt?: 0)
          required(:productType).filled(:string, included_in?: PRODUCT_TYPES)
          required(:securityId).filled(:string)
          optional(:price).maybe(:float, gt?: 0)
          optional(:triggerPrice).maybe(:float, gt?: 0)
        end
      end
    end
  end
end
