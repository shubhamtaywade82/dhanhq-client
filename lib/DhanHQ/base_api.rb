# frozen_string_literal: true

module DhanHQ
  # Base class for all API resource classes
  # Delegates HTTP requests to `DhanHQ::Client`
  class BaseAPI
    HTTP_PATH = ""
    attr_reader :client

    def initialize
      @client = DhanHQ::Client.new
    end

    # Perform a GET request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters
    # @return [Hash, Array] The parsed API response
    def get(endpoint = "", params: {})
      formatted_params = format_params(endpoint, params)
      client.get(build_path(endpoint), formatted_params)
    end

    # Perform a POST request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint = "", params: {})
      formatted_params = format_params(endpoint, params)
      client.post(build_path(endpoint), formatted_params)
    end

    # Perform a PUT request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint = "", params: {})
      formatted_params = format_params(endpoint, params)
      client.put(build_path(endpoint), formatted_params)
    end

    # Perform a DELETE request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @return [Hash, Array] The parsed API response
    def delete(endpoint = "")
      client.delete(build_path(endpoint))
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

      if optionchain_api?
        titleize_keys(params) # Convert to TitleCase for Option Chain APIs
      else
        camelize_keys(params) # Convert to camelCase for other APIs
      end
    end

    # Converts keys from snake_case to camelCase
    def camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    # Converts keys from snake_case to TitleCase
    def titleize_keys(hash)
      hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    end

    # Determines if the API endpoint is for Option Chain
    def optionchain_api?
      self.class::HTTP_PATH.include?("/optionchain")
    end
  end
end
