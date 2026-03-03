# frozen_string_literal: true

require "dry-validation"
require_relative "../constants"

module DhanHQ
  # Namespace housing Dry::Validation contracts for request payload validation.
  module Contracts
    # Base contract that includes shared logic and constants.
    class BaseContract < Dry::Validation::Contract
      # Include constants to make them accessible in all derived contracts
      include DhanHQ::Constants

      # Optional instrument metadata used by subcontracts for lot/tick size validation
      option :instrument_meta, optional: true

      register_macro(:lot_size_multiple) do
        meta = _contract.instrument_meta
        next unless meta && meta[:lot_size]

        ls = meta[:lot_size]
        key.failure("must be a multiple of lot size (#{ls})") if value && (value % ls != 0)
      end

      register_macro(:tick_size_multiple) do
        meta = _contract.instrument_meta
        next unless meta && meta[:tick_size]

        ts = meta[:tick_size]
        if value
          quotient = value.to_f / ts
          key.failure("must be a multiple of tick size (#{ts})") if (quotient - quotient.round).abs > 1e-6
        end
      end
    end
  end
end
