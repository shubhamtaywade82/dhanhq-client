# frozen_string_literal: true

require "faraday"
require "json"
require "active_support/core_ext/hash/indifferent_access"
require_relative "errors"
require_relative "rate_limiter"

module DhanHQ
  # The `Client` class provides a wrapper for HTTP requests to interact with the DhanHQ API.
  # Responsible for:
  # - Establishing and managing the HTTP connection
  # - Handling authentication and request headers
  # - Sending raw HTTP requests (`GET`, `POST`, `PUT`, `DELETE`)
  # - Parsing JSON responses into HashWithIndifferentAccess
  # - Handling standard HTTP errors (400, 401, 403, etc.)
  # - Implementing **Rate Limiting** to avoid hitting API limits.
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

    # Initializes a new DhanHQ Client instance with a Faraday connection.
    #
    # @example Create a new client:
    #   client = DhanHQ::Client.new(api_type: :order_api)
    #
    # @param api_type [Symbol] Type of API (`:order_api`, `:data_api`, `:non_trading_api`)
    # @return [DhanHQ::Client] A new client instance.
    def initialize(api_type:)
      @rate_limiter = RateLimiter.new(api_type)
      raise "RateLimiter initialization failed" unless @rate_limiter

      @connection = Faraday.new(url: DhanHQ.configuration.base_url) do |conn|
        conn.request :json, parser_options: { symbolize_names: true }
        conn.response :json, content_type: /\bjson$/
        conn.response :logger if ENV["DHAN_DEBUG"] == "true"
        conn.adapter Faraday.default_adapter
      end
    end

    # Sends an HTTP request to the API.
    #
    # @param method [Symbol] The HTTP method (`:get`, `:post`, `:put`, `:delete`)
    # @param path [String] The API endpoint path.
    # @param payload [Hash] The request parameters or body.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] Parsed JSON response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def request(method, path, payload)
      @rate_limiter.throttle! # **Ensure we don't hit rate limit before calling API**

      response = connection.send(method) do |req|
        req.url path
        req.headers.merge!(build_headers(path))
        prepare_payload(req, payload, method)
      end

      handle_response(response)
    end

    private

    # Dynamically builds headers for each request.
    #
    # @param path [String] The API endpoint path.
    # @return [Hash] The request headers.
    def build_headers(path)
      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "access-token" => DhanHQ.configuration.access_token
      }

      # Add client-id for DATA APIs
      headers["client-id"] = DhanHQ.configuration.client_id if data_api?(path)

      headers
    end

    # Determines if the API path requires a `client-id` header.
    #
    # @param path [String] The API endpoint path.
    # @return [Boolean] True if the path belongs to a DATA API.
    def data_api?(path)
      DhanHQ::Constants::DATA_API_PATHS.include?(path)
    end

    # Prepares the request payload based on the HTTP method.
    #
    # @param req [Faraday::Request] The request object.
    # @param payload [Hash] The request payload.
    # @param method [Symbol] The HTTP method.
    def prepare_payload(req, payload, method)
      return if payload.nil? || payload.empty?

      unless payload.is_a?(Hash)
        raise DhanHQ::InputExceptionError,
              "Invalid payload: Expected a Hash, got #{payload.class}"
      end

      case method
      when :delete then req.params = {}
      when :get then req.params = payload
      else req.body = payload.to_json
      end
    end

    # Handles the API response.
    #
    # @param response [Faraday::Response] The raw response object.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def handle_response(response)
      case response.status
      when 200..299 then parse_json(response.body)
      else handle_error(response)
      end
    end

    # Handles standard HTTP errors.
    #
    # @param response [Faraday::Response] The raw response object.
    # @raise [DhanHQ::Error] The specific error based on response status.
    def handle_error(response)
      body = parse_json(response.body)
      error_message = "#{response.status}: #{body[:error] || body[:message] || response.body}"

      case response.status
      when 400 then raise DhanHQ::InputExceptionError, "Bad Request: #{error_message}"
      when 401 then raise DhanHQ::InvalidAuthenticationError, "Unauthorized: #{error_message}"
      when 403 then raise DhanHQ::InvalidAccessError, "Forbidden: #{error_message}"
      when 404 then raise DhanHQ::NotFoundError, "Not Found: #{error_message}"
      when 429 then raise DhanHQ::RateLimitError, "Rate Limit Exceeded: #{error_message}"
      when 500..599 then raise DhanHQ::InternalServerError, "Server Error: #{error_message}"
      else
        raise DhanHQ::OtherError, "Unknown Error: #{error_message}"
      end
    end

    # Parses JSON response safely.
    #
    # @param body [String, Hash] The response body.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] The parsed JSON.
    def parse_json(body)
      parsed_body =
        if body.is_a?(String)
          begin
            JSON.parse(body, symbolize_names: true)
          rescue JSON::ParserError
            {} # Return an empty hash if the string is not valid JSON
          end
        else
          body
        end

      if parsed_body.is_a?(Hash)
        parsed_body.with_indifferent_access
      elsif parsed_body.is_a?(Array)
        parsed_body.map(&:with_indifferent_access)
      else
        parsed_body
      end
    end
  end
end
