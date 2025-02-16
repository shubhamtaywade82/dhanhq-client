# frozen_string_literal: true

module DhanHQ
  # Base class for all API resource classes
  # Delegates HTTP requests to `DhanHQ::Client`
  class BaseAPI
    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper
    include DhanHQ::RequestHelper
    include DhanHQ::ResponseHelper

    HTTP_PATH = ""

    attr_reader :client

    # Initializes the BaseAPI with the appropriate Client instance
    #
    # @param api_type [Symbol] API type (`:order_api`, `:data_api`, `:non_trading_api`)
    def initialize(api_type: :order_api)
      @client = DhanHQ::Client.new(api_type: api_type)
    end

    # Perform a GET request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters
    # @return [Hash, Array] The parsed API response
    def get(endpoint, params: {})
      request(:get, endpoint, params: params)
    end

    # Perform a POST request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint, params: {})
      request(:post, endpoint, params: params)
    end

    # Perform a PUT request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint, params: {})
      request(:put, endpoint, params: params)
    end

    # Perform a DELETE request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @return [Hash, Array] The parsed API response
    def delete(endpoint)
      request(:delete, endpoint)
    end

    private

    # Performs an API request.
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request parameters
    # @return [Hash, Array] The parsed API response
    # @raise [DhanHQ::Error] If an API error occurs.
    def request(method, endpoint, params: {})
      formatted_params = format_params(endpoint, params)
      response = client.request(method, build_path(endpoint), formatted_params)

      handle_response(response)
    end

    # Construct the complete API URL
    #
    # @param endpoint [String] API endpoint
    # @return [String] Full API path
    def build_path(endpoint)
      "#{self.class::HTTP_PATH}#{endpoint}"
    end

    # Format parameters based on API endpoint
    def format_params(endpoint, params)
      return params if params.empty?

      optionchain_api?(endpoint) ? titleize_keys(params) : camelize_keys(params)
    end

    # Determines if the API endpoint is for Option Chain
    def optionchain_api?(endpoint)
      endpoint.include?("/optionchain")
    end

    # # Handles API responses and raises errors if necessary
    # #
    # # @param response [Hash] API response
    # # @return [Hash, Array] Parsed API response
    # def handle_response(response)
    #   return response if response.is_a?(Array) || response.is_a?(Hash)

    #   raise DhanHQ::Error, "Unexpected API response format"
    # end

    # # Handles DhanHQ API-specific errors
    # #
    # # @param response [Hash] API response
    # # @raise [DhanHQ::Error] if an error is encountered
    # def handle_error(response)
    #   pp response
    #   error_code = response[:errorCode] || response[:status]
    #   error_message = response[:error] || response[:message] || response.to_s

    #   raise DhanHQ::Error, "API Error: #{error_message}" unless DhanHQ::Constants::DHAN_ERROR_MAPPING.key?(error_code)

    #   raise DhanHQ::Constants::DHAN_ERROR_MAPPING[error_code], "#{error_code}: #{error_message}"
    # end
  end
end
