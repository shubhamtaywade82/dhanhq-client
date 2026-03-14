# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for multi-leg super orders.
    class SuperOrders < BaseAPI
      # Super orders are executed via the trading API.
      API_TYPE = :order_api
      # Base path for super order endpoints.
      HTTP_PATH = "/v2/super/orders"

      # Lists all configured super orders.
      #
      # @return [Array<Hash>]
      def all
        get("")
      end

      # Creates a new super order.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        post("", params: params)
      end

      # Updates an existing super order.
      #
      # @param order_id [String]
      # @param params [Hash]
      # @return [Hash]
      def update(order_id, params)
        put("/#{order_id}", params: params)
      end

      SUPER_ORDER_LEGS = %w[ENTRY_LEG STOP_LOSS_LEG TARGET_LEG].freeze

      # Cancels a specific leg from a super order.
      #
      # @param order_id [String]
      # @param leg_name [String] One of ENTRY_LEG, STOP_LOSS_LEG, TARGET_LEG (per API path enum)
      # @return [Hash]
      # @raise [DhanHQ::ValidationError] if leg_name is not a valid leg
      def cancel(order_id, leg_name)
        normalized = leg_name.to_s.upcase.strip
        raise DhanHQ::ValidationError, "leg_name must be one of: #{SUPER_ORDER_LEGS.join(", ")}" unless SUPER_ORDER_LEGS.include?(normalized)

        delete("/#{order_id}/#{normalized}")
      end
    end
  end
end
