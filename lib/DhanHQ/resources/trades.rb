# frozen_string_literal: true

module DhanHQ
  module Resources
    class Trades < BaseAPI
      HTTP_PATH = "/v2/trades"

      # Retrieve the list of all trades for the day
      #
      # @return [Array<Hash>] The API response with the trade book
      def fetch_trades
        get
      end

      # Retrieve the details of trades by order ID
      #
      # @param order_id [String] Order ID
      # @return [Hash] The API response with trade details for the order
      def fetch_trades_by_order(order_id)
        get("/#{order_id}")
      end
    end
  end
end
