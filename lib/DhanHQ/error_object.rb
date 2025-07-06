# frozen_string_literal: true

module DhanHQ
  # Wrapper class for API error responses
  class ErrorObject
    # @return [Hash] Raw error response
    attr_reader :response

    # Initialize a new ErrorObject
    #
    # @param response [Hash] Parsed API response
    def initialize(response)
      @response =
        if response.is_a?(Hash)
          response.with_indifferent_access
        else
          { message: response.to_s }.with_indifferent_access
        end
    end

    # Always returns false to mimic success? interface on resources
    #
    # @return [Boolean]
    def success?
      false
    end

    # Extracts the error message from the response
    #
    # @return [String]
    def message
      response[:errorMessage] || response[:message] || response[:error] || "Unknown error"
    end

    # Error code if present
    #
    # @return [String, nil]
    def code
      response[:errorCode]
    end

    # Alias for the raw response hash
    #
    # @return [Hash]
    def errors
      response
    end
  end
end
