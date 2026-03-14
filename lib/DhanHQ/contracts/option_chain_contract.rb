# frozen_string_literal: true

require "date"

module DhanHQ
  module Contracts
    # Validates request for POST /v2/optionchain (option chain by underlying and expiry).
    # UnderlyingScrip (int), UnderlyingSeg (enum), Expiry (YYYY-MM-DD). Rate limit: 1 request per 3 seconds.
    class OptionChainContract < BaseContract
      params do
        required(:underlying_scrip).filled(:integer)
        required(:underlying_seg).filled(:string, included_in?: OPTION_CHAIN_UNDERLYING_SEGMENTS)
        required(:expiry).filled(:string)
      end

      rule(:expiry) do
        next unless value.is_a?(String)

        unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          key.failure("must be in YYYY-MM-DD format")
          next
        end

        Date.parse(value)
      rescue StandardError
        key.failure("must be a valid date")
      end
    end

    # Validates request for POST /v2/optionchain/expirylist (expiry list for an underlying).
    # UnderlyingScrip (int), UnderlyingSeg (enum). No Expiry.
    class OptionChainExpiryListContract < BaseContract
      params do
        required(:underlying_scrip).filled(:integer)
        required(:underlying_seg).filled(:string, included_in?: OPTION_CHAIN_UNDERLYING_SEGMENTS)
      end
    end
  end
end
