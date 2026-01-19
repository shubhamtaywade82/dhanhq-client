# frozen_string_literal: true

module DhanHQ
  # Helper mixin for normalising API responses and raising mapped errors.
  module ResponseHelper
    private

    # Determines if the API response indicates success.
    #
    # Treat responses missing a `:status` key but containing
    # an `orderId` or `orderStatus` as successful. This aligns with
    # certain Dhan APIs which return only order details on success.
    #
    # @param response [Hash] Parsed API response
    # @return [Boolean] True when the response signifies success
    def success_response?(response)
      return false unless response.is_a?(Hash)

      return true if response[:status] == "success"
      return true if response[:status].nil? && (response.key?(:orderId) || response.key?(:orderStatus))

      false
    end

    # Handles the API response.
    #
    # @param response [Faraday::Response] The raw response object.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def handle_response(response)
      case response.status
      when 200..201 then parse_json(response.body)
      when 202
        # 202 Accepted is used for async operations (e.g., position conversion)
        # Return status hash to indicate success for async operations
        { status: "accepted" }.with_indifferent_access
      when 203..299 then parse_json(response.body)
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
      if error_code == "DH-1111"
        error_message = "No holdings found for this account. Add holdings or wait for them to settle before retrying."
      end

      error_class = DhanHQ::Constants::DHAN_ERROR_MAPPING[error_code]

      unless error_class
        # Log unmapped error codes for investigation
        DhanHQ.logger&.warn("[DhanHQ] Unmapped error code: #{error_code} (status: #{response.status})")

        error_class =
          case response.status
          when 400 then DhanHQ::InputExceptionError
          when 401 then DhanHQ::InvalidAuthenticationError
          when 403 then DhanHQ::InvalidAccessError
          when 404 then DhanHQ::NotFoundError
          when 429 then DhanHQ::RateLimitError
          when 500..599 then DhanHQ::InternalServerError
          else DhanHQ::OtherError
          end
      end

      error_text =
        if error_code == "DH-1111"
          "#{error_message} (error code: #{error_code})"
        else
          "#{error_code}: #{error_message}"
        end

      raise error_class, error_text
    end

    # Parses JSON response safely. Converts response body to a hash or array with indifferent access.
    #
    # @param body [String, Hash] The response body.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed JSON.
    # @raise [DhanHQ::DataError] If JSON parsing fails (only for truly invalid JSON, not empty responses)
    def parse_json(body)
      parsed_body =
        if body.is_a?(String)
          # Handle empty strings gracefully (backward compatible)
          return {}.with_indifferent_access if body.strip.empty?

          begin
            JSON.parse(body, symbolize_names: true)
          rescue JSON::ParserError => e
            # Log error but maintain backward compatibility for edge cases
            # Only raise for clearly malformed JSON, not for empty/whitespace responses
            DhanHQ.logger&.error("[DhanHQ] JSON parse error: #{e.message}")
            DhanHQ.logger&.debug("[DhanHQ] Failed to parse body (first 200 chars): #{body[0..200]}")

            # Raise DataError for invalid JSON (this is an improvement, not a breaking change)
            # The API should never return invalid JSON, so this helps catch API issues
            raise DhanHQ::DataError, "Failed to parse JSON response: #{e.message}"
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
