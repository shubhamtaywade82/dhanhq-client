# frozen_string_literal: true

module DhanHQ
  module ResponseHelper
    private

    # Handles the API response.
    #
    # @param response [Faraday::Response] The raw response object.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def handle_response(response)
      case response.status
      when 200..299 then parse_json(response.body)
      else handle_error(response)
      end
    end

    # Handles standard HTTP errors.
    #
    # @param response [Faraday::Response] The raw response object.
    # @raise [DhanHQ::Error] The specific error based on response status.
    def handle_error(response)
      body = parse_json(response.body)

      error_code = body[:errorCode] || response.status.to_s
      error_message = body[:errorMessage] || body[:message] || "Unknown error"

      case response.status
      when 400 then raise DhanHQ::InputExceptionError, "Bad Request: #{error_message}"
      when 401 then raise DhanHQ::InvalidAuthenticationError, "Unauthorized: #{error_message}"
      when 403 then raise DhanHQ::InvalidAccessError, "Forbidden: #{error_message}"
      when 404 then raise DhanHQ::NotFoundError, "Not Found: #{error_message}"
      when 429 then raise DhanHQ::RateLimitError, "Rate Limit Exceeded: #{error_message}"
      when 500..599 then raise DhanHQ::InternalServerError, "Server Error: #{error_message}"
      else
        raise DhanHQ::OtherError, "Unknown Error: #{error_message}"
      end

      raise DhanHQ::Constants::DHAN_ERROR_MAPPING.fetch(error_code, DhanHQ::Error), "#{error_code}: #{error_message}"
    end

    # Parses JSON response safely. Converts response body to a hash or array with indifferent access.
    #
    # @param body [String, Hash] The response body.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed JSON.
    def parse_json(body)
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
