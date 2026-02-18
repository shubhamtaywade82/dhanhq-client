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
    AUTH_BASE_URL = "https://auth.dhan.co"
    API_BASE_URL  = "https://api.dhan.co/v2"

    # Generates an access token using TOTP authentication.
    #
    # POST https://auth.dhan.co/app/generateAccessToken
    #
    # @param dhan_client_id [String] Your Dhan client ID
    # @param pin [String] Your 6-digit Dhan PIN
    # @param totp [String] 6-digit TOTP code (or use generate_totp helper)
    # @return [Hash] Response hash with accessToken, expiryTime, etc.
    # @raise [DhanHQ::InvalidAuthenticationError] On authentication failure
    def self.generate_access_token(dhan_client_id:, pin:, totp:)
      conn = build_connection(AUTH_BASE_URL)

      response = conn.post("/app/generateAccessToken") do |req|
        req.headers["Accept"] = "application/json"

        req.params = {
          dhanClientId: dhan_client_id,
          pin: pin,
          totp: totp
        }
      end

      handle_response(response, context: "GenerateAccessToken")
    end

    # Renews a web-generated access token (24h validity).
    #
    # POST https://api.dhan.co/v2/RenewToken
    #
    # ⚠️ Works ONLY for tokens generated from Dhan Web dashboard.
    # For TOTP-generated tokens, regenerate instead of renewing.
    #
    # @param access_token [String] Current JWT access token
    # @param client_id [String] Dhan client ID (dhanClientId)
    # @return [Hash] Response hash with new accessToken and expiryTime
    # @raise [DhanHQ::InvalidAuthenticationError] On renewal failure
    def self.renew_token(access_token:, client_id:)
      conn = build_connection(API_BASE_URL)

      response = conn.post("/RenewToken") do |req|
        req.headers["access-token"] = access_token
        req.headers["dhanClientId"] = client_id
        req.headers["Accept"] = "application/json"
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

    private

    def self.build_connection(base_url)
      Faraday.new(url: base_url) do |c|
        c.request :url_encoded
        c.response :json, content_type: /\bjson$/
        c.adapter Faraday.default_adapter
      end
    end
    private_class_method :build_connection

    def self.handle_response(response, context:)
      unless response.success?
        body = response.body.is_a?(Hash) ? response.body : {}
        error_message = body["errorMessage"] || body["message"] || response.body.to_s

        raise DhanHQ::InvalidAuthenticationError,
              "#{context} failed: #{response.status} #{error_message}"
      end

      response.body.is_a?(Hash) ? response.body : {}
    end
    private_class_method :handle_response
  end
end
