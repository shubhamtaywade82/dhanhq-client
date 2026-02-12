# frozen_string_literal: true

require "time"

module DhanHQ
  module Models
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
