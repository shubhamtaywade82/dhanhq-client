# frozen_string_literal: true

module DhanHQ
  class ErrorHandler
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
