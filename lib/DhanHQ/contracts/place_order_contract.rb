# frozen_string_literal: true

module DhanHQ
  module Contracts
    class PlaceOrderContract < Dry::Validation::Contract
      params do
        required(:dhanClientId).filled(:string)
        required(:transactionType).filled(:string, included_in?: %w[BUY SELL])
        required(:exchangeSegment).filled(:string, included_in?: %w[NSE_EQ NSE_FNO BSE_EQ])
        required(:productType).filled(:string, included_in?: %w[CNC INTRADAY MARGIN MTF CO BO])
        required(:orderType).filled(:string, included_in?: %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET])
        required(:validity).filled(:string, included_in?: %w[DAY IOC])
        required(:securityId).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        optional(:disclosedQuantity).maybe(:integer)
        optional(:price).maybe(:float)
        optional(:triggerPrice).maybe(:float)
        optional(:afterMarketOrder).maybe(:bool)
        optional(:amoTime).maybe(:string, included_in?: %w[OPEN OPEN_30 OPEN_60])
        optional(:boProfitValue).maybe(:float)
        optional(:boStopLossValue).maybe(:float)
      end

      rule(:triggerPrice) do
        key.failure("is required for STOP_LOSS or STOP_LOSS_MARKET order types") if values[:orderType].in?(%w[STOP_LOSS
                                                                                                              STOP_LOSS_MARKET]) && value.nil?
      end
    end
  end
end
