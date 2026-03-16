# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource for P&L Based Exit endpoints per https://dhanhq.co/docs/v2/traders-control/
    # POST /v2/pnlExit — configure, DELETE /v2/pnlExit — stop, GET /v2/pnlExit — status.
    class PnlExit < BaseAPI
      include DhanHQ::Concerns::OrderAudit

      API_TYPE  = :order_api
      HTTP_PATH = "/v2/pnlExit"

      ##
      # Configure automatic P&L-based position exit.
      #
      # @param params [Hash] Request body with profitValue, lossValue, productType, enableKillSwitch.
      # @return [Hash] API response containing pnlExitStatus and message.
      def configure(params)
        ensure_live_trading!
        log_order_context("DHAN_PNL_EXIT_CONFIGURE_ATTEMPT", params)
        post("", params: params)
      end

      ##
      # Stop/disable the active P&L-based exit configuration.
      #
      # @return [Hash] API response containing pnlExitStatus and message.
      def stop
        ensure_live_trading!
        log_order_context("DHAN_PNL_EXIT_STOP_ATTEMPT")
        delete("")
      end

      ##
      # Fetch the currently active P&L-based exit configuration.
      #
      # @return [Hash] API response containing pnlExitStatus, profit, loss, segments, enable_kill_switch.
      def status
        get("")
      end
    end
  end
end
