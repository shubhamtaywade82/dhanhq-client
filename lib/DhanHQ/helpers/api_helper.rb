# frozen_string_literal: true

module DhanHQ
  # Helper mixin offering response validation behaviour for API wrappers.
  module APIHelper
    # Ensures the response is a structured payload before returning it.
    #
    # @param response [Hash, Array]
    # @return [Hash, Array]
    # @raise [DhanHQ::Error] When an unexpected payload type is received.
    def handle_response(response)
      return response if response.is_a?(Array) || response.is_a?(Hash)

      raise DhanHQ::Error, "Unexpected API response format"
    end
  end
end
