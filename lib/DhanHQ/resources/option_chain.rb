# frozen_string_literal: true

module DhanHQ
  module Resources
    class OptionChain < BaseAPI
      HTTP_PATH = "/v2"

      # Fetch the Option Chain for an underlying
      #
      # @param params [Hash] Parameters including `UnderlyingScrip`, `UnderlyingSeg`, and `Expiry`
      # @return [Hash] The API response with the option chain data
      def fetch_option_chain(params)
        post("/optionchain", params: params)
      end

      # Fetch the expiry list for options of an underlying
      #
      # @param params [Hash] Parameters including `UnderlyingScrip` and `UnderlyingSeg`
      # @return [Array<String>] List of expiry dates
      def fetch_expiry_list(params)
        post("/optionchain/expirylist", params: params)
      end
    end
  end
end
