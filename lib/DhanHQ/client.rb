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
    include DhanHQ::RequestHelper
    include DhanHQ::ResponseHelper
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
      error_code = body[:errorCode] || response.status.to_s
      error_message = body[:errorMessage] || body[:message] || "Unknown error"

      debugger
      raise DhanHQ::Constants::DHAN_ERROR_MAPPING.fetch(error_code, DhanHQ::Error), "#{error_code}: #{error_message}"
    end
    # def handle_error(response)
    #   body = parse_json(response.body)
    #   error_code = body[:errorCode] || response.status.to_s
    #   error_message = body[:errorMessage] || body[:message] || "Unknown error"

    #   debugger
    #   case response.status
    #   when 400 then raise DhanHQ::InputExceptionError, "Bad Request: #{error_message}"
    #   when 401 then raise DhanHQ::InvalidAuthenticationError, "Unauthorized: #{error_message}"
    #   when 403 then raise DhanHQ::InvalidAccessError, "Forbidden: #{error_message}"
    #   when 404 then raise DhanHQ::NotFoundError, "Not Found: #{error_message}"
    #   when 429 then raise DhanHQ::RateLimitError, "Rate Limit Exceeded: #{error_message}"
    #   when 500..599 then raise DhanHQ::InternalServerError, "Server Error: #{error_message}"
    #   else
    #     raise DhanHQ::OtherError, "Unknown Error: #{error_message}"
    #   end
    # end
  end
end
