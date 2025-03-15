# frozen_string_literal: true

module DhanHQ
  module Contracts
    class HistoricalDataContract < Dry::Validation::Contract
      params do
        # Common required fields
        required(:security_id).filled(:string)
        required(:exchange_segment).filled(:string, included_in?: %w[NSE_EQ NSE_FNO BSE_EQ])
        required(:instrument).filled(:string, included_in?: %w[EQUITY FUTIDX OPTIDX])

        # Date range required for both Daily & Intraday
        required(:from_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}\z/)
        required(:to_date).filled(:string, format?: /\A\d{4}-\d{2}-\d{2}\z/)

        # Optional fields
        optional(:expiry_code).maybe(:integer, included_in?: [0, 1, 2])

        # For intraday, the user can supply an "interval"
        # (valid: 1, 5, 15, 25, 60)
        optional(:interval).maybe(:string, included_in?: %w[1 5 15 25 60])
      end
    end
  end
end
