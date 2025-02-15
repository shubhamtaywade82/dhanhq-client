# frozen_string_literal: true

require_relative "helpers/api_helper"
require_relative "helpers/attribute_helper"
require_relative "helpers/request_helper"

module DhanHQ
  # Base class for all API resource classes
  # Delegates HTTP requests to `DhanHQ::Client`
  class BaseAPI
    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper
    include DhanHQ::RequestHelper

    ERROR_MAPPING = {
      "DH-901" => DhanHQ::InvalidAuthenticationError,
      "DH-902" => DhanHQ::InvalidAccessError,
      "DH-903" => DhanHQ::UserAccountError,
      "DH-904" => DhanHQ::RateLimitError,
      "DH-905" => DhanHQ::InputExceptionError,
      "DH-906" => DhanHQ::OrderError,
      "DH-907" => DhanHQ::DataError,
      "DH-908" => DhanHQ::InternalServerError,
      "DH-909" => DhanHQ::NetworkError,
      "DH-910" => DhanHQ::OtherError,
      "800" => DhanHQ::InternalServerError,
      "804" => DhanHQ::Error, # Too many instruments
      "805" => DhanHQ::RateLimitError, # Too many requests
      "806" => DhanHQ::DataError, # Data API not subscribed
      "807" => DhanHQ::InvalidTokenError, # Token expired
      "808" => DhanHQ::AuthenticationFailedError, # Auth failed
      "809" => DhanHQ::InvalidTokenError, # Invalid token
      "810" => DhanHQ::InvalidClientIDError, # Invalid Client ID
      "811" => DhanHQ::InvalidRequestError, # Invalid expiry date
      "812" => DhanHQ::InvalidRequestError, # Invalid date format
      "813" => DhanHQ::InvalidRequestError, # Invalid security ID
      "814" => DhanHQ::InvalidRequestError # Invalid request
    }.freeze

    HTTP_PATH = ""

    attr_reader :client

    # Initializes the BaseAPI with the appropriate Client instance
    #
    # @param api_type [Symbol] API type (`:order_api`, `:data_api`, `:non_trading_api`)
    def initialize(api_type: :order_api)
      @client = DhanHQ::Client.new(api_type: api_type)
    end

    # Performs an API request.
    #
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request parameters
    # @return [Hash, Array] The parsed API response
    # @raise [DhanHQ::Error] If an API error occurs.
    def request(method, endpoint = "", params: {})
      formatted_params = format_params(endpoint, params)
      response = client.request(method, build_path(endpoint), formatted_params)

      handle_response(response)
    rescue DhanHQ::Error => e
      handle_error({ errorCode: e.class::CODE, message: e.message })
    end

    # Perform a GET request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters
    # @return [Hash, Array] The parsed API response
    def get(endpoint = "", params: {})
      request(:get, endpoint, params: params)
    end

    # Perform a POST request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint = "", params: {})
      request(:post, endpoint, params: params)
    end

    # Perform a PUT request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint = "", params: {})
      request(:put, endpoint, params: params)
    end

    # Perform a DELETE request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @return [Hash, Array] The parsed API response
    def delete(endpoint = "")
      request(:delete, endpoint)
    end

    private

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

    # Handles API responses and raises errors if necessary
    #
    # @param response [Hash] API response
    # @return [Hash, Array] Parsed API response
    def handle_response(response)
      return response if response.is_a?(Array) || response.is_a?(Hash)

      raise DhanHQ::Error, "Unexpected API response format"
    end

    # Handles DhanHQ API-specific errors
    #
    # @param response [Hash] API response
    # @raise [DhanHQ::Error] if an error is encountered
    def handle_error(response)
      error_code = response[:errorCode] || response[:status]
      error_message = response[:error] || response[:message] || response.to_s

      if ERROR_MAPPING.key?(error_code)
        raise ERROR_MAPPING[error_code],
              "#{ERROR_MAPPING[error_code].name.split("::").last.gsub("Error", "")}: #{error_message}"
      end

      raise DhanHQ::Error, "Unknown API error: #{error_message}"
    end
  end
end
