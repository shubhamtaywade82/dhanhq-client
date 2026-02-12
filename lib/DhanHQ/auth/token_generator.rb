module DhanHQ
  module Auth
    # Backward-compatible wrapper for token generation.
    # Delegates to module-level Auth.generate_access_token.
    class TokenGenerator
      def generate(dhan_client_id:, pin:, totp: nil, totp_secret: nil)
        otp = resolve_totp(totp, totp_secret)

        response = Auth.generate_access_token(
          dhan_client_id: dhan_client_id,
          pin: pin,
          totp: otp
        )

        Models::TokenResponse.new(response)
      end

      private

      def resolve_totp(totp, secret)
        totp = totp.to_s.strip
        return totp unless totp.empty?

        secret = secret.to_s.strip
        raise ArgumentError, "Provide `totp` or `totp_secret` (e.g. ENV['DHAN_TOTP_SECRET'])" if secret.empty?

        Auth.generate_totp(secret)
      end
    end
  end
end
