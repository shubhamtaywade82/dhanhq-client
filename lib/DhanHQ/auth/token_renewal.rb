# frozen_string_literal: true

module DhanHQ
  module Auth
    # Backward-compatible wrapper for token renewal.
    # Delegates to module-level Auth.renew_token.
    class TokenRenewal
      def renew
        config = DhanHQ.configuration
        raise DhanHQ::AuthenticationError, "Missing configuration" unless config

        access_token = config.resolved_access_token
        dhan_client_id = config.client_id
        raise DhanHQ::AuthenticationError, "Missing dhanClientId (client_id)" if dhan_client_id.to_s.strip.empty?

        response = Auth.renew_token(
          access_token: access_token,
          client_id: dhan_client_id
        )

        Models::TokenResponse.new(response)
      end
    end
  end
end
