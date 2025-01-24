# frozen_string_literal: true

require "dry-validation"

module DhanHQ
  module Contracts
    class OrderContract < Dry::Validation::Contract
      params do
        required(:dhanClientId).filled(:string)
        required(:transactionType).filled(:string, included_in?: %w[BUY SELL])
        required(:productType).filled(:string, included_in?: %w[CNC INTRADAY MARGIN])
        required(:securityId).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        required(:price).filled(:float, gt?: 0)
        optional(:triggerPrice).maybe(:float, gt?: 0)
        optional(:validity).maybe(:string, included_in?: %w[DAY IOC])
      end
    end
  end
end
