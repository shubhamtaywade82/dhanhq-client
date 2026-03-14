# frozen_string_literal: true

module DhanHQ
  module Resources
    # The path /trader-control is not part of the Dhan v2 API (https://dhanhq.co/docs/v2).
    # Trader's Control in the docs is implemented via:
    #   - Kill Switch: GET/POST /v2/killswitch → use DhanHQ::Models::KillSwitch or DhanHQ::Resources::KillSwitch
    #   - P&L Exit:    GET/POST/DELETE /v2/pnlExit → use DhanHQ::Models::PnlExit
    #
    # This class is kept for backward compatibility but raises when used.
    class TraderControl < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/trader-control"

      MSG = "The /trader-control endpoint is not part of the Dhan v2 API. " \
            "Use DhanHQ::Models::KillSwitch or DhanHQ::Resources::KillSwitch for kill switch " \
            "(GET/POST /v2/killswitch). See https://dhanhq.co/docs/v2"

      def status
        raise DhanHQ::Error, MSG
      end

      def enable
        raise DhanHQ::Error, MSG
      end

      def disable
        raise DhanHQ::Error, MSG
      end
    end
  end
end
