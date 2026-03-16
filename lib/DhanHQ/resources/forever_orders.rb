# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource client for GTT/forever order management.
    class ForeverOrders < BaseAPI
      include DhanHQ::Concerns::OrderAudit

      # Uses the trading API tier.
      API_TYPE = :order_api
      # Root path for forever order operations.
      HTTP_PATH = "/v2/forever"

      # Lists all forever orders for the account.
      #
      # @return [Array<Hash>]
      def all
        get("/orders")
      end

      # Creates a new forever order configuration.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        ensure_live_trading!
        log_order_context("DHAN_FOREVER_ORDER_ATTEMPT", params)
        post("/orders", params: params)
      end

      # Fetches a forever order by identifier.
      #
      # @param order_id [String]
      # @return [Hash]
      def find(order_id)
        get("/orders/#{order_id}")
      end

      # Updates a forever order.
      #
      # @param order_id [String]
      # @param params [Hash]
      # @return [Hash]
      def update(order_id, params)
        ensure_live_trading!
        log_order_context("DHAN_FOREVER_ORDER_MODIFY_ATTEMPT", params.merge(order_id: order_id))
        put("/orders/#{order_id}", params: params)
      end

      # Cancels a forever order.
      #
      # @param order_id [String]
      # @return [Hash]
      def cancel(order_id)
        ensure_live_trading!
        log_order_context("DHAN_FOREVER_ORDER_CANCEL_ATTEMPT", { order_id: order_id })
        delete("/orders/#{order_id}")
      end
    end
  end
end
