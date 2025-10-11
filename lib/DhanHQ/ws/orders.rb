# frozen_string_literal: true

require_relative "orders/client"

module DhanHQ
  module WS
    # Namespaces helpers related to the orders WebSocket channel.
    module Orders
      # Establishes an order WebSocket connection and yields each update.
      #
      # @yieldparam payload [Hash] payload emitted for an order update
      def self.connect(&)
        Client.new.start.on(:update, &)
      end
    end
  end
end
