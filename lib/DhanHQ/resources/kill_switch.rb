# frozen_string_literal: true

require "cgi"

module DhanHQ
  module Resources
    # Resource client to control the trading kill switch feature.
    # API expects killSwitchStatus as query parameter (no body). See dhanhq.co/docs/v2/traders-control/
    class KillSwitch < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/v2/killswitch"

      # Enables or disables the kill switch via query parameter (doc: no body).
      #
      # @param status [String] "ACTIVATE" or "DEACTIVATE"
      # @return [Hash]
      def update(status)
        query = "?killSwitchStatus=#{CGI.escape(status.to_s)}"
        handle_response(client.post(build_path(query), {}))
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
