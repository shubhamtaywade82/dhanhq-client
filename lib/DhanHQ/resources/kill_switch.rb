# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client to control the trading kill switch feature.
    class KillSwitch < BaseAPI
      # Kill switch operations execute on the trading API tier.
      API_TYPE = :order_api
      # Base path for kill switch operations.
      HTTP_PATH = "/v2/killswitch"

      # Enables or disables the kill switch.
      #
      # @param params [Hash]
      # @return [Hash]
      def update(params)
        post("", params: params)
      end

      ##
      # Fetches the current kill switch status.
      #
      # @return [Hash] API response containing dhan_client_id and kill_switch_status.
      def status
        get("")
      end
    end
  end
end
