# frozen_string_literal: true

require "cgi"

module DhanHQ
  module Resources
    # Resource client to control the trading kill switch feature.
    # API expects killSwitchStatus as query parameter (no body). See dhanhq.co/docs/v2/traders-control/
    class KillSwitch < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/v2/killswitch"

      KILL_SWITCH_STATUSES = %w[ACTIVATE DEACTIVATE].freeze

      # Enables or disables the kill switch via query parameter (doc: no body).
      #
      # @param status [String] "ACTIVATE" or "DEACTIVATE"
      # @return [Hash]
      # @raise [DhanHQ::ValidationError] if status is not ACTIVATE or DEACTIVATE
      def update(status)
        normalized = status.to_s.upcase.strip
        raise DhanHQ::ValidationError, "killSwitchStatus must be one of: #{KILL_SWITCH_STATUSES.join(", ")}" unless KILL_SWITCH_STATUSES.include?(normalized)

        query = "?killSwitchStatus=#{CGI.escape(normalized)}"
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
