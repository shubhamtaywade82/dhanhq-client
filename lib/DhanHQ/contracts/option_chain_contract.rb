# frozen_string_literal: true

require_relative "base_contract"

module DhanHQ
  module Contracts
    # **Validation contract for fetching option chain data**
    #
    # Validates request parameters for fetching option chains & expiry lists.
    class OptionChainContract < BaseContract
      params do
        required(:underlying_scrip).filled(:integer) # Security ID
        required(:underlying_seg).filled(:string, included_in?: %w[IDX_I NSE_FNO BSE_FNO MCX_FO])
        required(:expiry).filled(:string)
      end

      rule(:expiry) do
        # Ensure the expiry date is in "YYYY-MM-DD" format
        key.failure("must be in 'YYYY-MM-DD' format") unless value.match?(/^\d{4}-\d{2}-\d{2}$/)

        # Ensure it is a valid date
        begin
          parsed_date = Date.parse(value)
          key.failure("must be a valid date") unless parsed_date.to_s == value
        rescue ArgumentError
          key.failure("is not a valid date")
        end
      end
    end
  end
end
