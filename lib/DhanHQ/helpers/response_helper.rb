# frozen_string_literal: true

module DhanHQ
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
      if error_code == "DH-1111"
        error_message = "No holdings found for this account. Add holdings or wait for them to settle before retrying."
      end

      error_class = DhanHQ::Constants::DHAN_ERROR_MAPPING[error_code]

      error_class ||=
        case response.status
        when 400 then DhanHQ::InputExceptionError
        when 401 then DhanHQ::InvalidAuthenticationError
        when 403 then DhanHQ::InvalidAccessError
        when 404 then DhanHQ::NotFoundError
        when 429 then DhanHQ::RateLimitError
        when 500..599 then DhanHQ::InternalServerError
        else DhanHQ::OtherError
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
