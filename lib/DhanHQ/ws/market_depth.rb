# frozen_string_literal: true

require_relative "market_depth/client"

module DhanHQ
  module WS
    module MarketDepth
      ##
      # Market Depth WebSocket module for real-time market depth data
      # Provides access to bid/ask levels and order book depth

      module_function

      ##
      # Connect to Market Depth WebSocket with a simple callback
      # @param symbols [Array<String>] Symbols to subscribe to
      # @param options [Hash] Connection options
      # @param block [Proc] Callback for depth updates
      # @return [Client] WebSocket client instance
      def connect(symbols: [], **, &)
        client = Client.new(symbols: symbols, **)
        client.on(:depth_update, &) if block_given?
        client.start
      end

      ##
      # Create a new Market Depth client with advanced features
      # @param symbols [Array<String>] Symbols to subscribe to
      # @param options [Hash] Connection options
      # @return [Client] New client instance
      def client(symbols: [], **)
        Client.new(symbols: symbols, **)
      end

      ##
      # Quick connection with multiple event handlers
      # @param symbols [Array<String>] Symbols to subscribe to
      # @param handlers [Hash] Event handlers
      # @param options [Hash] Connection options
      # @return [Client] Started client instance
      def connect_with_handlers(symbols: [], handlers: {}, **)
        client = Client.new(symbols: symbols, **).start

        handlers.each do |event, handler|
          client.on(event, &handler)
        end

        client
      end

      ##
      # Subscribe to market depth for specific symbols
      # @param symbols [Array<String>] Symbols to subscribe to
      # @param options [Hash] Connection options
      # @param block [Proc] Callback for depth updates
      # @return [Client] Started client instance
      def subscribe(symbols:, **, &)
        connect(symbols: symbols, **, &)
      end

      ##
      # Get market depth snapshot for symbols
      # @param symbols [Array<String>] Symbols to get snapshot for
      # @param options [Hash] Connection options
      # @param block [Proc] Callback for snapshot data
      # @return [Client] Started client instance
      def snapshot(symbols:, **, &)
        client = Client.new(symbols: symbols, **)
        client.on(:depth_snapshot, &) if block_given?
        client.start
      end
    end
  end
end
