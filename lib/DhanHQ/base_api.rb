# frozen_string_literal: true

module DhanHQ
  class BaseAPI
    def initialize
      @client = DhanHQ::Client.new
    end

    # Dynamically build the base path for the resource
    def resource_path
      "/#{self.class.name.split("::").last.underscore}"
    end

    # Perform a GET request
    def get(endpoint = "", params: {})
      perform_request(:get, build_path(endpoint), params: params)
    end

    # Perform a POST request
    def post(endpoint = "", params: {})
      perform_request(:post, build_path(endpoint), params: params)
    end

    # Perform a PUT request
    def put(endpoint = "", params: {})
      perform_request(:put, build_path(endpoint), params: params)
    end

    # Perform a DELETE request
    def delete(endpoint = "")
      perform_request(:delete, build_path(endpoint))
    end

    private

    # Build the complete path by appending the endpoint to the resource path
    def build_path(endpoint)
      "#{resource_path}#{endpoint}"
    end

    # Perform the actual request
    def perform_request(method, endpoint, params: {})
      response = @client.request(method, endpoint, params: params, headers: build_headers)
      handle_response(response)
    rescue StandardError => e
      handle_error(e)
    end

    # Build the default headers for API requests
    def build_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{DhanHQ.configuration.api_key}"
      }
    end

    # Handle the API response
    def handle_response(response)
      case response[:status]
      when "success"
        response
      else
        raise ApiError.new(response[:message], response[:errors])
      end
    end

    # Handle API errors
    def handle_error(error)
      raise ApiError.new(error.message, error.backtrace)
    end

    # Default headers for API requests
    def default_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{DhanHQ.configuration.api_key}"
      }
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
