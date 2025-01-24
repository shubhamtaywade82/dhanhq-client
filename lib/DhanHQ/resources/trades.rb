# frozen_string_literal: true

module DhanHQ
  module Resources
    class Trades < BaseAPI
      # Fetch trades for a specific order
      def fetch_by_order(order_id)
        get("/#{order_id}")
      end

      # Fetch all trades for the day
      def fetch_all
        get
      end
    end
  end
end
