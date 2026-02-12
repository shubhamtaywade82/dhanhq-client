# frozen_string_literal: true

require "monitor"

module DhanHQ
  module Auth
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
