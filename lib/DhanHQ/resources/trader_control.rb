# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource for trader control (kill switch): status (GET), enable/disable (POST /trader-control).
    class TraderControl < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/trader-control"

      def status
        get("")
      end

      def enable
        post("", params: { action: "ENABLE" })
      end

      def disable
        post("", params: { action: "DISABLE" })
      end
    end
  end
end
