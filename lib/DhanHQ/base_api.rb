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

    HTTP_PATH = ""

    attr_reader :client

    def initialize
      @client = DhanHQ::Client.new
    end

    def request(method, endpoint = "", params: {})
      formatted_params = format_params(endpoint, params)
      client.send(method, build_path(endpoint), formatted_params)
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
    def format_params(_endpoint, params)
      return params if params.empty?

      optionchain_api? ? titleize_keys(params) : camelize_keys(params)
    end

    # Determines if the API endpoint is for Option Chain
    def optionchain_api?
      self.class::HTTP_PATH.include?("/optionchain")
    end
  end
end
