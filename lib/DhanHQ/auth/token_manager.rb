# frozen_string_literal: true

require "monitor"

module DhanHQ
  module Auth
    # Manages automatic token lifecycle including generation, renewal, and validation.
    #
    # TokenManager provides production-grade token automation by:
    # - Generating new tokens via TOTP when needed
    # - Renewing tokens before expiry (5-minute buffer)
    # - Falling back to full generation if renewal fails
    # - Thread-safe token operations via Monitor lock
    #
    # @example Enable auto token management
    #   client = DhanHQ::Client.new(api_type: :order_api)
    #   client.enable_auto_token_management!(
    #     dhan_client_id: ENV["DHAN_CLIENT_ID"],
    #     pin: ENV["DHAN_PIN"],
    #     totp_secret: ENV["DHAN_TOTP_SECRET"]
    #   )
    #
    # @example Manual usage
    #   manager = TokenManager.new(
    #     dhan_client_id: "123",
    #     pin: "1234",
    #     totp_secret: "SECRET"
    #   )
    #   manager.ensure_valid_token!  # Auto-generates or renews as needed
    #
    # @see Auth::TokenGenerator for TOTP-based token generation
    # @see Auth::TokenRenewal for token renewal logic
    class TokenManager
      def initialize(dhan_client_id:, pin:, totp_secret:)
        @dhan_client_id = dhan_client_id
        @pin = pin
        @totp_secret = totp_secret

        @token = nil
        @lock = Monitor.new
      end

      def generate!
        @lock.synchronize do
          token = Auth::TokenGenerator.new.generate(
            dhan_client_id: @dhan_client_id,
            pin: @pin,
            totp_secret: @totp_secret
          )

          apply_token(token)
        end
      end

      def ensure_valid_token!
        return generate! unless @token

        return unless @token.needs_refresh?

        refresh!
      end

      def refresh!
        @lock.synchronize do
          return generate! unless @token

          renewal = Auth::TokenRenewal.new.renew
          apply_token(renewal)
        rescue Errors::AuthenticationError
          generate!
        end
      end

      private

      def apply_token(token)
        @token = token

        DhanHQ.configure do |config|
          config.access_token = token.access_token
          config.client_id = token.client_id if token.client_id.to_s.strip != ""
        end

        token
      end
    end
  end
end
