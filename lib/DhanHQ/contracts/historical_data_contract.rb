# frozen_string_literal: true

module DhanHQ
  module Contracts
    class HistoricalDataContract < Dry::Validation::Contract
      params do
        required(:securityId).filled(:string)
        required(:exchangeSegment).filled(:string, included_in?: %w[NSE_EQ NSE_FNO BSE_EQ])
        required(:instrument).filled(:string, included_in?: %w[EQUITY FUTIDX OPTIDX])
        optional(:expiryCode).maybe(:integer, included_in?: [0, 1, 2])
        required(:fromDate).filled(:string, format?: /\d{4}-\d{2}-\d{2}/)
        required(:toDate).filled(:string, format?: /\d{4}-\d{2}-\d{2}/)
      end
    end
  end
end
