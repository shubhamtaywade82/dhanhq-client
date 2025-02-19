# frozen_string_literal: true

module DhanHQ
  module APIHelper
    def handle_response(response)
      return response if response.is_a?(Array) || response.is_a?(Hash)

      raise DhanHQ::Error, "Unexpected API response format"
    end
  end
end
