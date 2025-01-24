# frozen_string_literal: true

require "faraday"
require "json"
require "active_support/core_ext/hash/indifferent_access"

module DhanHQ
  # The `Client` class provides a wrapper for HTTP requests to interact with the DhanHQ API.
  #
  # It supports `GET`, `POST`, `PUT`, and `DELETE` requests with JSON encoding/decoding.
  # Credentials (`access_token`, `client_id`) are automatically added to each request.
  #
  # @see https://dhanhq.co/docs/v2/ DhanHQ API Documentation
  class Client
    # The Faraday connection object used for HTTP requests.
    #
    # @return [Faraday::Connection] The connection instance used for API requests.
    attr_reader :connection

    # Initializes a new DhanHQ Client instance.
    #
    # @example Create a new client:
    #   client = DhanHQ::Client.new
    #
    # @return [DhanHQ::Client] A new client instance configured for API requests.
    def initialize
      @connection = Faraday.new(url: DhanHQ.configuration.base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :logger if ENV["DHAN_DEBUG"]
        conn.adapter Faraday.default_adapter
      end
    end

    # Sends a GET request to the API.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] The query parameters for the GET request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def get(path, params = {})
      request(:get, path, params)
    end

    # Sends a POST request to the API.
    #
    # @param path [String] The API endpoint path.
    # @param body [Hash] The body of the POST request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def post(path, body = {})
      request(:post, path, body)
    end

    # Sends a PUT request to the API.
    #
    # @param path [String] The API endpoint path.
    # @param body [Hash] The body of the PUT request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def put(path, body = {})
      request(:put, path, body)
    end

    # Sends a DELETE request to the API.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] The query parameters for the DELETE request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def delete(path, params = {})
      request(:delete, path, params)
    end

    private

    # Handles HTTP requests to the DhanHQ API.
    #
    # @param method [Symbol] The HTTP method (e.g., :get, :post, :put, :delete).
    # @param path [String] The API endpoint path.
    # @param payload [Hash] The parameters or body for the request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def request(method, path, payload)
      response = connection.send(method) do |req|
        req.url path
        headers(req)
        prepare_payload(req, payload, method)
      end
      handle_response(response)
    end

    # Sets headers for the request.
    #
    # @param req [Faraday::Request] The request object.
    # @return [void]
    def headers(req)
      req.headers["access-token"] = DhanHQ.configuration.access_token
      req.headers["client-id"] = DhanHQ.configuration.client_id
      req.headers["Accept"] = "application/json"
      req.headers["Content-Type"] = "application/json"
    end

    # Prepares the request payload.
    #
    # @param req [Faraday::Request] The request object.
    # @param payload [Hash] The payload for the request.
    # @param method [Symbol] The HTTP method.
    # @return [void]
    def prepare_payload(req, payload, method)
      if method == :get
        req.params = payload if payload.is_a?(Hash)
      elsif payload.is_a?(Hash)
        payload[:dhanClientId] ||= DhanHQ.configuration.client_id
        req.body = payload.to_json
      end
    end

    # Handles the API response.
    #
    # @param response [Faraday::Response] The response object.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response status indicates an error.
    def handle_response(response)
      case response.status
      when 200..299
        symbolize_keys(response.body)
      else
        handle_error(response)
      end
    end

    # Handles errors in the API response.
    #
    # @param response [Faraday::Response] The response object.
    # @return [void]
    # @raise [DhanHQ::Error] The specific error based on the response status.
    def handle_error(response)
      error_message = "#{response.status}: #{response.body}"
      case response.status
      when 400 then raise DhanHQ::Error, "Bad Request: #{error_message}"
      when 401 then raise DhanHQ::Error, "Unauthorized: #{error_message}"
      when 403 then raise DhanHQ::Error, "Forbidden: #{error_message}"
      when 404 then raise DhanHQ::Error, "Not Found: #{error_message}"
      when 500..599 then raise DhanHQ::Error, "Server Error: #{error_message}"
      else raise DhanHQ::Error, "Unknown Error: #{error_message}"
      end
    end

    # Converts response body to a hash with indifferent access.
    #
    # @param body [String, Hash] The response body.
    # @return [Hash] The response body as a hash with indifferent access.
    def symbolize_keys(body)
      body.is_a?(Hash) ? body.with_indifferent_access : body
    end
  end
end
