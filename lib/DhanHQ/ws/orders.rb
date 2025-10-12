# frozen_string_literal: true

require_relative "orders/client"

module DhanHQ
  module WS
    # WebSocket orders module for real-time order updates
    module Orders
      def self.connect(&)
        Client.new.start.on(:update, &)
      end
    end
  end
end
