# frozen_string_literal: true

module DhanHQ
  module RequestHelper
    # Converts response body to a hash or array with indifferent access.
    #
    # @param body [String, Hash, Array] The response body.
    # @return [Hash, Array] The response body as a hash/array with indifferent access.
    def symbolize_keys(body)
      parsed_body =
        if body.is_a?(String)
          begin
            JSON.parse(body, symbolize_names: true)
          rescue JSON::ParserError
            {} # Return an empty hash if the string is not valid JSON
          end
        else
          body
        end

      if parsed_body.is_a?(Hash)
        parsed_body.with_indifferent_access
      elsif parsed_body.is_a?(Array)
        parsed_body.map(&:with_indifferent_access)
      else
        parsed_body
      end
    end
  end
end
