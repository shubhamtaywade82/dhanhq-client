# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates payloads used to modify an existing order.
    class ModifyOrderContract < Dry::Validation::Contract
      params do
        required(:dhanClientId).filled(:string)
        required(:orderId).filled(:string)
        optional(:orderType).maybe(:string, included_in?: %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET])
        optional(:quantity).maybe(:integer)
        optional(:price).maybe(:float)
        optional(:triggerPrice).maybe(:float)
        optional(:disclosedQuantity).maybe(:integer)
        optional(:validity).maybe(:string, included_in?: %w[DAY IOC])
      end

      rule(:quantity) do
        key.failure("must be provided if modifying quantity") if value.nil? && values[:price].nil?
      end
    end
  end
end
