# frozen_string_literal: true

module DhanHQ
  # Base class for all API resource classes
  # Handles HTTP requests, error handling, and dynamic path building
  class BaseAPI
    def initialize
      @client = DhanHQ::Client.new
    end

    # Dynamically build the base path for the resource
    #
    # @return [String] The base resource path
    def resource_path
      self.class::HTTP_PATH
    end

    # Perform a GET request
    #
    # @param endpoint [String] The endpoint to append to the resource path
    # @param params [Hash] Query parameters for the request
    # @return [Hash, Array] The parsed API response
    def get(endpoint = "", params: {})
      perform_request(:get, build_path(endpoint), params: params)
    end

    # Perform a POST request
    #
    # @param endpoint [String] The endpoint to append to the resource path
    # @param params [Hash] The request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint = "", params: {})
      perform_request(:post, build_path(endpoint), params: params)
    end

    # Perform a PUT request
    #
    # @param endpoint [String] The endpoint to append to the resource path
    # @param params [Hash] The request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint = "", params: {})
      perform_request(:put, build_path(endpoint), params: params)
    end

    # Perform a DELETE request
    #
    # @param endpoint [String] The endpoint to append to the resource path
    # @return [Hash, Array] The parsed API response
    def delete(endpoint = "")
      perform_request(:delete, build_path(endpoint))
    end

    private

    # Build the complete path by appending the endpoint to the resource path
    #
    # @param endpoint [String] The endpoint to append
    # @return [String] The full path
    def build_path(endpoint)
      "#{resource_path}#{endpoint}"
    end

    # Perform the actual request
    #
    # @param method [Symbol] The HTTP method (e.g., :get, :post)
    # @param endpoint [String] The full path of the API
    # @param params [Hash] Request parameters
    # @return [Hash, Array] The parsed API response
    def perform_request(method, endpoint, params: {})
      response = @client.request(method, endpoint, params: add_client_id(params), headers: build_headers)
      handle_response(response)
    rescue StandardError => e
      handle_error(e)
    end

    # Build the default headers for API requests
    #
    # @return [Hash] The default headers
    def build_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{DhanHQ.configuration.access_token}"
      }
    end

    # Add dhanClientId to request parameters
    #
    # @param params [Hash] The request parameters
    # @return [Hash] The parameters including dhanClientId
    def add_client_id(params)
      params.merge(dhanClientId: DhanHQ.configuration.client_id)
    end

    # Handle the API response
    #
    # @param response [Hash] The API response
    # @return [Hash, Array] The parsed response
    # @raise [ApiError] If the response indicates an error
    def handle_response(response)
      case response[:status]
      when "success"
        response
      else
        raise ApiError.new(response[:message], response[:errors])
      end
    end

    # Handle API errors
    #
    # @param error [StandardError] The raised error
    # @raise [ApiError] The formatted API error
    def handle_error(error)
      raise ApiError.new(error.message, error.backtrace)
    end
  end

  # Custom error class for API-related errors
  class ApiError < StandardError
    attr_reader :errors

    def initialize(message, errors = nil)
      super(message)
      @errors = errors || {}
    end
  end
end
