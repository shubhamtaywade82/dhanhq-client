# frozen_string_literal: true

require_relative "orders/client"

module DhanHQ
  module WS
    ##
    # WebSocket orders module for real-time order updates
    # Provides comprehensive order state tracking and event handling
    module Orders
      ##
      # Connect to order updates WebSocket with a simple callback
      # @param block [Proc] Callback for order updates
      # @return [Client] WebSocket client instance
      def self.connect(&)
        Client.new.start.on(:update, &)
      end

      ##
      # Create a new order updates client with advanced features
      # @param url [String, nil] Optional custom WebSocket URL
      # @return [Client] New client instance
      def self.client(url: nil)
        Client.new(url: url)
      end

      ##
      # Quick connection with multiple event handlers
      # @param handlers [Hash] Event handlers
      # @return [Client] Started client instance
      def self.connect_with_handlers(handlers = {})
        client = Client.new.start

        handlers.each do |event, handler|
          client.on(event, &handler)
        end

        client
      end
    end
  end
end
