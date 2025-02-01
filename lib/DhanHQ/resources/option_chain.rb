# frozen_string_literal: true

module DhanHQ
  module Resources
    class OptionChain < BaseAPI
      HTTP_PATH = "/v2/optionchain"

      # Fetch Option Chain Data for a specific underlying security
      #
      # @param params [Hash] Parameters for fetching the option chain
      # @return [Hash] The API response containing the option chain
      def fetch_option_chain(params)
        formatted_params = format_params_for_option_chain(params)
        post("", params: formatted_params)
      end

      # Fetch Expiry List for an underlying security
      #
      # @param params [Hash] Parameters for fetching expiry dates
      # @return [Array] The API response containing expiry dates
      def fetch_expiry_list(params)
        formatted_params = format_params_for_option_chain(params)
        post("/expirylist", params: formatted_params)
      end

      private

      # Convert request parameters to PascalCase for the Option Chain API
      #
      # @param params [Hash] Request parameters
      # @return [Hash] Parameters formatted with PascalCase keys
      def format_params_for_option_chain(params)
        params.transform_keys { |key| key.to_s.split("_").map(&:capitalize).join }
      end
    end
  end
end
