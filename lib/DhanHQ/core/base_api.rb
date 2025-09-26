# frozen_string_literal: true

module DhanHQ
  # Base class for all API resource classes.
  # Delegates HTTP requests to {DhanHQ::Client} and exposes helpers shared by
  # resource wrappers.
  class BaseAPI
    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper

    # Default API type used when a subclass does not override {#initialize}.
    API_TYPE = :non_trading_api
    # Root path prepended to each endpoint segment.
    HTTP_PATH = ""

    attr_reader :client

    # Initializes the BaseAPI with the appropriate Client instance
    #
    # @param api_type [Symbol] API type (`:order_api`, `:data_api`, `:non_trading_api`)
    def initialize(api_type: self.class::API_TYPE)
      @client = DhanHQ::Client.new(api_type: api_type)
    end

    # Perform a GET request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters
    # @return [Hash, Array] The parsed API response
    def get(endpoint, params: {})
      formatted_params = format_params(endpoint, params)
      handle_response(client.get(build_path(endpoint), formatted_params))
    end

    # Perform a POST request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint, params: {})
      formatted_params = format_params(endpoint, params)
      handle_response(client.post(build_path(endpoint), formatted_params))
    end

    # Perform a PUT request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint, params: {})
      formatted_params = format_params(endpoint, params)
      handle_response(client.put(build_path(endpoint), formatted_params))
    end

    # Perform a DELETE request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @return [Hash, Array] The parsed API response
    def delete(endpoint)
      formatted_params = format_params(endpoint, {})
      handle_response(client.delete(build_path(endpoint), formatted_params))
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
      return params if marketfeed_api?(endpoint) || params.empty?

      optionchain_api?(endpoint) ? titleize_keys(params) : camelize_keys(params)
    end

    # Determines if the API endpoint is for Option Chain
    def optionchain_api?(endpoint)
      endpoint.include?("/optionchain")
    end

    def marketfeed_api?(endpoint)
      endpoint.include?("/marketfeed")
    end
  end
end
