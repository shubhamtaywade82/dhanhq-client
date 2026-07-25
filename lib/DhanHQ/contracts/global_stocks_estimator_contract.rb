# frozen_string_literal: true

require_relative "base_contract"

module DhanHQ
  module Contracts
    # Validation contract shared by POST /v2/globalstocks/transEstimate
    # (order charge estimate) and POST /v2/globalstocks/margincalculator.
    #
    # Both endpoints accept the same +InxEstimatorRequest+ body. The API documents
    # +price+ and +quantity+ as strings on the wire; this contract validates them
    # as numbers and the resource stringifies them before sending.
    class GlobalStocksEstimatorContract < BaseContract
      TRANSACTION_TYPES = DhanHQ::Constants::TransactionType::ALL

      params do
        required(:security_id).filled(:string, max_size?: 50)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:price).filled(:float, gteq?: 0)
        required(:quantity).filled(:float, gt?: 0)
      end

      rule(:price) do
        key.failure("must be a finite number") if value.is_a?(Float) && (value.nan? || value.infinite?)
      end
    end
  end
end
