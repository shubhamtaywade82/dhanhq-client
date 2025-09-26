# frozen_string_literal: true

module DhanHQ
  # Helper mixin used by models and clients to assemble API requests.
  module RequestHelper
    # Builds a model object from API response
    #
    # @param response [Hash] API response
    # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject]
    def build_from_response(response)
      return DhanHQ::ErrorObject.new(response) unless success_response?(response)

      attributes = if response.is_a?(Hash) && response[:data].is_a?(Hash)
                     response[:data]
                   else
                     response
                   end

      new(attributes, skip_validation: true)
    end

    private

    # Dynamically builds headers for each request.
    #
    # @param path [String] The API endpoint path.
    # @return [Hash] The request headers.
    def build_headers(path)
      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "access-token" => DhanHQ.configuration.access_token
      }

      # Add client-id for DATA APIs
      headers["client-id"] = DhanHQ.configuration.client_id if data_api?(path)

      headers
    end

    # Determines if the API path requires a `client-id` header.
    #
    # @param path [String] The API endpoint path.
    # @return [Boolean] True if the path belongs to a DATA API.
    def data_api?(path)
      DhanHQ::Constants::DATA_API_PATHS.include?(path)
    end

    # Prepares the request payload based on the HTTP method.
    #
    # @param req [Faraday::Request] The request object.
    # @param payload [Hash] The request payload.
    # @param method [Symbol] The HTTP method.
    def prepare_payload(req, payload, method)
      return if payload.nil? || payload.empty?

      unless payload.is_a?(Hash)
        raise DhanHQ::InputExceptionError,
              "Invalid payload: Expected a Hash, got #{payload.class}"
      end

      case method
      when :delete then req.params = {}
      when :get then req.params = payload
      else req.body = payload.to_json
      end
    end
  end
end
