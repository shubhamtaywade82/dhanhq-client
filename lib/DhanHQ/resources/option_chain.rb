# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for querying option chain data APIs.
    class OptionChain < BaseAPI
      # Option chain queries have bespoke rate limits, hence their own API type.
      API_TYPE = :option_chain
      # Base path for option chain endpoints.
      HTTP_PATH = "/v2/optionchain"

      ##
      # Fetch option chain data based on provided parameters.
      #
      # @param params [Hash] Query parameters for the request.
      # @return [Hash] API response containing option chain data.
      def fetch(params)
        post("", params: params)
      end

      ##
      # Fetch expiry dates list based on provided parameters.
      #
      # @param params [Hash] Query parameters for the request.
      # @return [Hash] API response containing option chain data.
      def expirylist(params)
        post("/expirylist", params: params)
      end
    end
  end
end
