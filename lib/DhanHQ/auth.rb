# frozen_string_literal: true

require "faraday"
require "json"
require "rotp"
require_relative "errors"

module DhanHQ
  # Module-level helpers for Dhan authentication APIs.
  #
  # Supports:
  # - Generating access tokens via TOTP (for automated systems)
  # - Renewing web-generated tokens (web-only tokens)
  #
  # @example Generate token with TOTP
  #   totp = DhanHQ::Auth.generate_totp(ENV["DHAN_TOTP_SECRET"])
  #   response = DhanHQ::Auth.generate_access_token(
  #     dhan_client_id: ENV["DHAN_CLIENT_ID"],
  #     pin: ENV["DHAN_PIN"],
  #     totp: totp
  #   )
  #   token = response["accessToken"]
  #
  # @example Renew web token
  #   response = DhanHQ::Auth.renew_token(
  #     access_token: current_token,
  #     client_id: ENV["DHAN_CLIENT_ID"]
  #   )
  module Auth
    AUTH_BASE_URL = Constants::Urls::AUTH_BASE
    API_BASE_URL  = Constants::Urls::REST_API_BASE

    # Generates an access token using TOTP authentication.
    #
    # POST https://auth.dhan.co/app/generateAccessToken
    #
    # @param dhan_client_id [String] Your Dhan client ID
    # @param pin [String] Your 6-digit Dhan PIN
    # @param totp [String] 6-digit TOTP code (or use generate_totp helper)
    # @return [Hash] Response hash with accessToken, expiryTime, etc.
    # @raise [DhanHQ::InvalidAuthenticationError] When Dhan rejects the credentials
    # @raise [DhanHQ::RateLimitError, DhanHQ::InternalServerError, DhanHQ::NetworkError] On retryable failures
    def self.generate_access_token(dhan_client_id:, pin:, totp:)
      response = perform("GenerateAccessToken") do
        # Relative path: a leading slash would make Faraday discard the base URL's path.
        build_connection(AUTH_BASE_URL).post("app/generateAccessToken") do |req|
          req.headers["Accept"] = "application/json"
          req.params = { dhanClientId: dhan_client_id, pin: pin, totp: totp }
        end
      end

      handle_response(response, context: "GenerateAccessToken")
    end

    # Renews a web-generated access token (24h validity).
    #
    # GET https://api.dhan.co/v2/RenewToken
    #
    # ⚠️ Works ONLY for tokens generated from Dhan Web dashboard, and only while
    # the token is still active; renewing an expired token returns an error.
    # For TOTP-generated tokens, regenerate instead of renewing.
    #
    # @param access_token [String] Current JWT access token
    # @param client_id [String] Dhan client ID (dhanClientId)
    # @return [Hash] Response hash with new accessToken and expiryTime
    # @raise [DhanHQ::InvalidAuthenticationError] When Dhan rejects the token
    # @raise [DhanHQ::RateLimitError, DhanHQ::InternalServerError, DhanHQ::NetworkError] On retryable failures
    def self.renew_token(access_token:, client_id:)
      response = perform("RenewToken") do
        # Relative path keeps the /v2 base. GET, per Dhan's documented curl
        # example and the official Python SDK.
        build_connection(API_BASE_URL).get("RenewToken") do |req|
          req.headers["access-token"] = access_token
          req.headers["dhanClientId"] = client_id
          req.headers["Accept"] = "application/json"
        end
      end

      handle_response(response, context: "RenewToken")
    end

    # Generates a 6-digit TOTP code from a secret.
    #
    # @param secret [String] TOTP secret (from authenticator app setup)
    # @return [String] 6-digit TOTP code
    def self.generate_totp(secret)
      ROTP::TOTP.new(secret).now
    end

    # Bounded timeouts, same defaults as Client#build_connection: a stalled auth
    # endpoint must not hang the caller.
    def self.build_connection(base_url)
      Faraday.new(url: base_url) do |c|
        c.request :url_encoded
        c.options.timeout = ENV.fetch("DHAN_READ_TIMEOUT", 30).to_i
        c.options.open_timeout = ENV.fetch("DHAN_CONNECT_TIMEOUT", 10).to_i
        c.options.write_timeout = ENV.fetch("DHAN_WRITE_TIMEOUT", 30).to_i
        c.adapter Faraday.default_adapter
      end
    end
    private_class_method :build_connection

    def self.perform(context)
      yield
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise DhanHQ::NetworkError, "#{context} request failed: #{e.class}: #{e.message}"
    end
    private_class_method :perform

    # Rate limits and server errors are retryable; everything else means the
    # credentials themselves were refused.
    def self.handle_response(response, context:)
      body = parse_body(response.body)
      return body if response.success?

      message = body["errorMessage"] || body["message"] || response.body.to_s
      raise error_class_for(response.status).new("#{context} failed: #{response.status} #{message}".strip, response_body: body)
    end
    private_class_method :handle_response

    def self.error_class_for(status)
      case status
      when 429 then DhanHQ::RateLimitError
      when 500..599 then DhanHQ::InternalServerError
      else DhanHQ::InvalidAuthenticationError
      end
    end
    private_class_method :error_class_for

    # Dhan does not always label responses as JSON, so parse whatever arrives.
    def self.parse_body(body)
      return body if body.is_a?(Hash)
      return {} if body.to_s.strip.empty?

      JSON.parse(body.to_s)
    rescue JSON::ParserError
      {}
    end
    private_class_method :parse_body
  end
end
