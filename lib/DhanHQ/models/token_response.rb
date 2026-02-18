# frozen_string_literal: true

require "time"

module DhanHQ
  module Models
    # Represents a Dhan API token response with expiry tracking and validation.
    #
    # TokenResponse wraps the response from Dhan's token generation and renewal
    # endpoints, providing convenient methods for checking token validity and
    # determining when refresh is needed.
    #
    # @example From token generation
    #   response = Auth.generate_access_token(
    #     dhan_client_id: "123",
    #     pin: "1234",
    #     totp: "654321"
    #   )
    #   token = TokenResponse.new(response)
    #   token.expired?       # => false
    #   token.expires_in     # => 86400 (seconds)
    #   token.needs_refresh? # => false
    #
    # @example Checking token status
    #   if token.needs_refresh?(buffer_seconds: 600)
    #     # Refresh token 10 minutes before expiry
    #     new_token = Auth.renew_token(...)
    #   end
    #
    # @attr_reader [String] client_id Dhan client ID
    # @attr_reader [String] client_name Dhan client name
    # @attr_reader [String] ucc Unique client code
    # @attr_reader [Boolean] power_of_attorney POA status
    # @attr_reader [String] access_token The authentication token
    # @attr_reader [Time] expiry_time Token expiration timestamp
    class TokenResponse
      attr_reader :client_id,
                  :client_name,
                  :ucc,
                  :power_of_attorney,
                  :access_token,
                  :expiry_time

      def initialize(data)
        data = normalize_keys(data)

        @client_id = data["dhanClientId"]
        @client_name = data["dhanClientName"]
        @ucc = data["dhanClientUcc"]
        @power_of_attorney = data["givenPowerOfAttorney"]
        @access_token = data["accessToken"]
        @expiry_time = parse_time(data["expiryTime"])
      end

      def expired?
        return true unless expiry_time

        Time.now >= expiry_time
      end

      def expires_in
        return 0 unless expiry_time

        expiry_time - Time.now
      end

      def needs_refresh?(buffer_seconds: 300)
        return true unless expiry_time

        Time.now >= (expiry_time - buffer_seconds)
      end

      private

      def normalize_keys(data)
        return {} unless data.is_a?(Hash)

        data.transform_keys(&:to_s)
      end

      def parse_time(value)
        return nil if value.nil? || value.to_s.strip.empty?

        Time.parse(value.to_s)
      end
    end
  end
end
