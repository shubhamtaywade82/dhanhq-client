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

    attr_reader :token_manager

    # Initializes a new DhanHQ Client instance with a Faraday connection.
    #
    # @example Create a new client:
    #   client = DhanHQ::Client.new(api_type: :order_api)
    #
    # @param api_type [Symbol] Type of API (`:order_api`, `:data_api`, `:non_trading_api`)
    # @return [DhanHQ::Client] A new client instance.
    # @raise [DhanHQ::Error] If configuration is invalid or rate limiter initialization fails
    def initialize(api_type:)
      # Configure from ENV if DHAN_CLIENT_ID is present (backward compatible behavior)
      # Validation happens at request time in build_headers, not here
      DhanHQ.configure_with_env if ENV.fetch("DHAN_CLIENT_ID", nil)

      # Use shared rate limiter instance per API type to ensure proper coordination
      @rate_limiter = RateLimiter.for(api_type)

      raise DhanHQ::Error, "RateLimiter initialization failed" unless @rate_limiter

      # Get timeout values from configuration or environment, with sensible defaults
      connect_timeout = ENV.fetch("DHAN_CONNECT_TIMEOUT", 10).to_i
      read_timeout = ENV.fetch("DHAN_READ_TIMEOUT", 30).to_i
      write_timeout = ENV.fetch("DHAN_WRITE_TIMEOUT", 30).to_i

      @connection = Faraday.new(url: DhanHQ.configuration.base_url) do |conn|
        conn.request :json, parser_options: { symbolize_names: true }
        conn.response :json, content_type: /\bjson$/
        conn.response :logger if ENV["DHAN_DEBUG"] == "true"
        conn.options.timeout = read_timeout
        conn.options.open_timeout = connect_timeout
        conn.options.write_timeout = write_timeout
        conn.adapter Faraday.default_adapter
      end
    end

    # Sends an HTTP request to the API with automatic retry for transient errors.
    #
    # @param method [Symbol] The HTTP method (`:get`, `:post`, `:put`, `:delete`)
    # @param path [String] The API endpoint path.
    # @param payload [Hash] The request parameters or body.
    # @param retries [Integer] Number of retries for transient errors (default: 3)
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] Parsed JSON response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def request(method, path, payload, retries: 3)
      @token_manager&.ensure_valid_token!
      @rate_limiter.throttle! # **Ensure we don't hit rate limit before calling API**

      attempt = 0
      auth_retry_done = false
      begin
        response = connection.send(method) do |req|
          req.url path
          req.headers.merge!(build_headers(path))
          prepare_payload(req, payload, method)
        end

        handle_response(response)
      rescue DhanHQ::InvalidAuthenticationError, DhanHQ::InvalidTokenError,
             DhanHQ::TokenExpiredError, DhanHQ::AuthenticationFailedError => e
        config = DhanHQ.configuration
        if !auth_retry_done && config&.access_token_provider
          auth_retry_done = true
          config.on_token_expired&.call(e)
          DhanHQ.logger&.warn("[DhanHQ::Client] Auth failure (#{e.class}), retrying once with fresh token")
          retry
        end
        raise
      rescue DhanHQ::RateLimitError, DhanHQ::InternalServerError, DhanHQ::NetworkError => e
        attempt += 1
        if attempt <= retries
          backoff_time = calculate_backoff(attempt)
          DhanHQ.logger&.warn("[DhanHQ::Client] Transient error (#{e.class}), retrying in #{backoff_time}s (attempt #{attempt}/#{retries})")
          sleep(backoff_time)
          retry
        end
        raise
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        attempt += 1
        if attempt <= retries
          backoff_time = calculate_backoff(attempt)
          DhanHQ.logger&.warn("[DhanHQ::Client] Network error (#{e.class}), retrying in #{backoff_time}s (attempt #{attempt}/#{retries})")
          sleep(backoff_time)
          retry
        end
        raise DhanHQ::NetworkError, "Request failed after #{retries} retries: #{e.message}"
      end
    end

    # Convenience wrapper for issuing a GET request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] Query parameters for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def get(path, params = {})
      request(:get, path, params)
    end

    # Convenience wrapper for issuing a POST request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] JSON payload for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def post(path, params = {})
      request(:post, path, params)
    end

    # Convenience wrapper for issuing a PUT request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] JSON payload for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def put(path, params = {})
      request(:put, path, params)
    end

    # Convenience wrapper for issuing a DELETE request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] Optional request payload (rare for DELETE).
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def delete(path, params = {})
      request(:delete, path, params)
    end

    def generate_access_token(dhan_client_id:, pin:, totp: nil, totp_secret: nil)
      token = Auth::TokenGenerator.new.generate(
        dhan_client_id: dhan_client_id,
        pin: pin,
        totp: totp,
        totp_secret: totp_secret
      )

      DhanHQ.configure do |config|
        config.access_token = token.access_token
        config.client_id = token.client_id if token.client_id.to_s.strip != ""
      end

      token
    end

    def renew_access_token
      token = Auth::TokenRenewal.new.renew

      DhanHQ.configure do |config|
        config.access_token = token.access_token
        config.client_id = token.client_id if token.client_id.to_s.strip != ""
      end

      token
    end

    def enable_auto_token_management!(dhan_client_id:, pin:, totp_secret:)
      @token_manager = Auth::TokenManager.new(
        dhan_client_id: dhan_client_id,
        pin: pin,
        totp_secret: totp_secret
      )

      @token_manager.generate!
    end

    private

    # Calculates exponential backoff time
    #
    # @param attempt [Integer] Current attempt number (1-based)
    # @return [Float] Backoff time in seconds
    def calculate_backoff(attempt)
      # Exponential backoff: 1s, 2s, 4s, 8s, etc., capped at 30s
      [2**(attempt - 1), 30].min.to_f
    end
  end
end
