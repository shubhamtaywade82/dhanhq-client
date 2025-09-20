# frozen_string_literal: true

module DhanHQ
  module Resources
    ##
    # Provides access to the user profile endpoint.
    #
    # The endpoint is a simple GET request to `/v2/profile` that returns
    # account level metadata (token validity, active segments, etc.).
    class Profile < BaseAPI
      API_TYPE = :non_trading_api
      HTTP_PATH = "/v2/profile"

      ##
      # Fetch the authenticated user's profile information.
      #
      # @return [Hash] Parsed response from the profile endpoint.
      def fetch
        get("")
      end
    end
  end
end

