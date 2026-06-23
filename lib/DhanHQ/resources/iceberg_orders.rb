# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource client for Iceberg order management.
    class IcebergOrders < BaseAPI
      include DhanHQ::Concerns::OrderAudit

      API_TYPE = :order_api
      HTTP_PATH = "/v2/orders/iceberg"

      # Lists all iceberg orders for the account.
      #
      # @return [Array<Hash>]
      def all
        get("")
      end

      # Creates a new iceberg order.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        ensure_live_trading!
        log_order_context("DHAN_ICEBERG_ORDER_ATTEMPT", params)
        post("", params: params)
      end

      # Fetches a specific iceberg order by ID.
      #
      # @param order_id [String]
      # @return [Hash]
      def find(order_id)
        get("/#{order_id}")
      end

      # Updates an existing iceberg order.
      #
      # @param order_id [String]
      # @param params [Hash]
      # @return [Hash]
      def update(order_id, params)
        ensure_live_trading!
        log_order_context("DHAN_ICEBERG_ORDER_MODIFY_ATTEMPT", params.merge(order_id: order_id))
        put("/#{order_id}", params: params)
      end

      # Cancels an iceberg order.
      #
      # @param order_id [String]
      # @return [Hash]
      def cancel(order_id)
        ensure_live_trading!
        log_order_context("DHAN_ICEBERG_ORDER_CANCEL_ATTEMPT", { order_id: order_id })
        delete("/#{order_id}")
      end
    end
  end
end
