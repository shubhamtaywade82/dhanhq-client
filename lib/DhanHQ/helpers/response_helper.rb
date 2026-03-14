# frozen_string_literal: true

module DhanHQ
  # Helper mixin for normalising API responses and raising mapped errors.
  module ResponseHelper
    STATUS_ERROR_FALLBACK = {
      400 => DhanHQ::InputExceptionError,
      401 => DhanHQ::InvalidAuthenticationError,
      403 => DhanHQ::InvalidAccessError,
      404 => DhanHQ::NotFoundError,
      429 => DhanHQ::RateLimitError
    }.freeze

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
      if error_code == DhanHQ::Constants::TradingErrorCode::NO_HOLDINGS
        error_message = "No holdings found for this account. Add holdings or wait for them to settle before retrying."
      end

      error_class = DhanHQ::Constants::DHAN_ERROR_MAPPING[error_code]
      unless error_class
        DhanHQ.logger&.warn("[DhanHQ] Unmapped error code: #{error_code} (status: #{response.status})")
        error_class = status_fallback_error_class(response.status)
      end

      message = build_error_text(error_code, error_message, body)
      raise error_class.new(message, response_body: body)
    end

    def status_fallback_error_class(status)
      STATUS_ERROR_FALLBACK[status] ||
        (status.between?(500, 599) ? DhanHQ::InternalServerError : DhanHQ::OtherError)
    end

    def build_error_text(error_code, error_message, body = {})
      text = if error_code == DhanHQ::Constants::TradingErrorCode::NO_HOLDINGS
               "#{error_message} (error code: #{error_code})"
             else
               "#{error_code}: #{error_message}"
             end

      extra = extra_error_detail(body)
      text += " | #{extra}" if extra

      if error_code == DhanHQ::Constants::TradingErrorCode::INPUT_EXCEPTION
        text += " (API does not return which field failed; check required params and value types for this endpoint.)"
      end

      text
    end

    # Returns any additional error detail from the response body (errors array, details, etc.).
    def extra_error_detail(body)
      return nil unless body.is_a?(Hash)

      parts = []
      if body[:errors].is_a?(Array) && body[:errors].any?
        parts << body[:errors].join("; ")
      end
      if body[:details].is_a?(String) && body[:details].to_s.strip != ""
        parts << body[:details].to_s
      end
      if body[:validationErrors].is_a?(Array) && body[:validationErrors].any?
        parts << body[:validationErrors].map { |e| e.is_a?(Hash) ? e[:message] || e[:field] : e }.join("; ")
      end
      parts.empty? ? nil : parts.join(" ")
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
