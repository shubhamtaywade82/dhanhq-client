# frozen_string_literal: true

module DhanHQ
  module APIHelper
    # Provides a reusable API client instance
    #
    # @return [DhanHQ::Client] The client instance
    def api_client
      @api_client ||= DhanHQ::Client.new
    end

    # Executes an API request
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request parameters
    # @return [Hash, Array] Parsed API response
    def request(method, endpoint, params = {})
      response = api_client.send(method, endpoint, params)
      handle_response(response)
    end

    # Checks if API response is successful
    #
    # @param response [Hash] API response
    # @return [Boolean] True if status is success
    def success_response?(response)
      response[:status] == "success"
    end

    private

    # Handles API responses and raises errors if needed
    #
    # @param response [Hash] API response
    # @return [Hash, Array] Parsed response data
    # def handle_response(response)
    #   return response[:data] if success_response?(response)

    #   raise DhanHQ::Error, response[:message] || "API request failed"
    # end

    # Handles API responses and raises errors if necessary
    #
    # @param response [Hash] API response
    # @return [Hash, Array] Parsed API response
    def handle_response(response)
      return response if response.is_a?(Array) || response.is_a?(Hash)

      raise DhanHQ::Error, "Unexpected API response format"
    end
  end
end
