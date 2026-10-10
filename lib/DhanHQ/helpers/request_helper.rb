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

    def current_config
      if respond_to?(:config) && config
        config
      elsif respond_to?(:client) && client.respond_to?(:config) && client.config
        client.config
      else
        DhanHQ.configuration
      end
    end

    # Dynamically builds headers for each request.
    #
    # @param path [String] The API endpoint path.
    # @return [Hash] The request headers.
    # @raise [DhanHQ::InvalidAuthenticationError] If required headers are missing
    def build_headers(path)
      # Public CSV endpoint for segment-wise instruments requires no auth
      return { "Accept" => "text/csv" } if path.start_with?("/v2/instrument/")

      token = resolved_access_token
      raise DhanHQ::AuthenticationError, "Missing access token" if token.nil? || token.empty?

      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "access-token" => token
      }

      # Add client-id for DATA APIs (now including sandbox profile/funds)
      if data_api?(path)
        client_id = current_config&.client_id
        unless client_id
          raise DhanHQ::InvalidAuthenticationError,
                "client_id is required for DATA APIs but not set. Please configure DhanHQ with DHAN_CLIENT_ID."
        end
        headers["client-id"] = client_id
      end

      headers
    end

    def resolved_access_token
      current_config&.resolved_access_token
    end

    # Determines if the API path requires a `client-id` header.
    #
    # @param path [String] The API endpoint path.
    # @return [Boolean] True if the path belongs to a DATA API.
    def data_api?(path)
      prefixes = DhanHQ::Constants::DATA_API_PREFIXES
      prefixes.any? { |p| path.start_with?(p) }
    end

    # Injects +dhanClientId+ into payloads destined for endpoints whose wire
    # contract requires it. Called by Client#request BEFORE contract validation
    # so the validator sees the payload exactly as it will hit the wire;
    # {#prepare_payload} calls this too and is idempotent.
    #
    # @param method [Symbol]
    # @param path [String, nil]
    # @param payload [Hash]
    # @return [Hash] the payload (a dup when injection happened)
    def with_injected_client_id(method, path, payload)
      return payload unless payload.is_a?(Hash)
      return payload unless path && %i[post put patch].include?(method)
      # Mirror prepare_payload's early return: empty bodies on non-data paths
      # were never injected before contract validation existed, and changing
      # their wire shape now would break recorded-fixture consumers.
      return payload if payload.empty? && !data_api?(path)

      client_id = current_config&.client_id
      needs_client_id = data_api?(path) || payload_requires_dhan_client_id?(path)
      return payload if client_id.nil? || !needs_client_id
      return payload if payload.key?(:dhanClientId) || payload.key?("dhanClientId")

      out = payload.dup
      if out.keys.any?(String)
        out["dhanClientId"] = client_id
      else
        out[:dhanClientId] = client_id
      end
      out
    end

    # Prepares the request payload based on the HTTP method.
    #
    # @param req [Faraday::Request] The request object.
    # @param payload [Hash] The request payload.
    # @param method [Symbol] The HTTP method.
    def prepare_payload(req, payload, method, path = nil)
      return if payload.nil? || (payload.empty? && (path.nil? || !data_api?(path)))

      unless payload.is_a?(Hash)
        raise DhanHQ::InputExceptionError,
              "Invalid payload: Expected a Hash, got #{payload.class}"
      end

      out = with_injected_client_id(method, path, payload)

      case method
      when :delete then req.params = {}
      when :get then req.params = out
      else req.body = out.to_json
      end
    end

    # True when the path is one where the request body must include dhanClientId (order-api style).
    def payload_requires_dhan_client_id?(path)
      return false if path.nil? || path.empty?

      prefixes = DhanHQ::Constants::PAYLOAD_REQUIRES_DHAN_CLIENT_ID_PREFIXES
      prefixes.any? { |p| path.start_with?(p) }
    end
  end
end
