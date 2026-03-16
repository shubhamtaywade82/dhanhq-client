# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource for alert/conditional orders per API docs: /alerts/orders (GET/POST/PUT/DELETE).
    class AlertOrders < BaseResource
      include DhanHQ::Concerns::OrderAudit

      API_TYPE  = :order_api
      HTTP_PATH = "/v2/alerts/orders"

      # Creates a new alert/conditional order.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        ensure_live_trading!
        log_order_context("DHAN_ALERT_ORDER_ATTEMPT", params)
        post("", params: params)
      end

      # Updates an existing alert/conditional order.
      #
      # @param id [String, Integer]
      # @param params [Hash]
      # @return [Hash]
      def update(id, params)
        log_order_context("DHAN_ALERT_ORDER_MODIFY_ATTEMPT", params.merge(alert_id: id))
        put("/#{id}", params: params)
      end
    end
  end
end
