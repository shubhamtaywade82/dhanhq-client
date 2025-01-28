# frozen_string_literal: true

module DhanHQ
  module Contracts
    class MarginCalculatorContract < Dry::Validation::Contract
      params do
        required(:dhanClientId).filled(:string)
        required(:exchangeSegment).filled(:string, included_in?: %w[NSE_EQ NSE_FNO BSE_EQ])
        required(:transactionType).filled(:string, included_in?: %w[BUY SELL])
        required(:quantity).filled(:integer, gt?: 0)
        required(:productType).filled(:string, included_in?: %w[CNC INTRADAY MARGIN MTF CO BO])
        required(:securityId).filled(:string)
        required(:price).filled(:float, gt?: 0)
        optional(:triggerPrice).maybe(:float)
      end
    end
  end
end
