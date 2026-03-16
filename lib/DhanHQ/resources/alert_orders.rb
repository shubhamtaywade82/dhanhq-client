# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource for alert/conditional orders per API docs: /alerts/orders (GET/POST/PUT/DELETE).
    class AlertOrders < BaseResource
      include DhanHQ::Concerns::OrderAudit

      API_TYPE  = :order_api
      HTTP_PATH = "/v2/alerts/orders"

      def create(params)
        ensure_live_trading!
        log_order_context("DHAN_ALERT_ORDER_ATTEMPT", params)
        super
      end

      def update(id, params)
        ensure_live_trading!
        log_order_context("DHAN_ALERT_ORDER_MODIFY_ATTEMPT", params.merge(alert_id: id))
        super
      end

      def delete(id)
        ensure_live_trading!
        log_order_context("DHAN_ALERT_ORDER_DELETE_ATTEMPT", { order_id: id })
        super
      end
    end
  end
end
