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
    end
  end
end
