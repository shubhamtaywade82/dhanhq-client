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

      # Declare options that can be passed during initialization
      option :lot_size, optional: true
      option :tick_size, optional: true

      register_macro(:lot_size_multiple) do
        ls = _contract.lot_size
        key.failure("must be a multiple of lot size (#{ls})") if ls && value && (value % ls != 0)
      end

      register_macro(:tick_size_multiple) do
        ts = _contract.tick_size
        if ts && value
          # Using precision-safe comparison for financial tick sizes
          quotient = value.to_f / ts
          key.failure("must be a multiple of tick size (#{ts})") if (quotient - quotient.round).abs > 1e-6
        end
      end
    end
  end
end
