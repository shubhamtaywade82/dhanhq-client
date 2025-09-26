# frozen_string_literal: true

module DhanHQ
  # Provides a minimal shim for surfacing validation and runtime errors.
  class ErrorHandler
    # Normalises the exception raised for various error types.
    #
    # @param error [Dry::Validation::Result, StandardError]
    # @raise [RuntimeError]
    def self.handle(error)
      case error
      when Dry::Validation::Result
        raise "Validation Error: #{error.errors.to_h}"
      else
        raise "Error: #{error.message}"
      end
    end
  end
end
