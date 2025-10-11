# frozen_string_literal: true

require "concurrent"
require_relative "connection"

module DhanHQ
  module WS
    module Orders
      # Manages lifecycle and event dispatching for the orders WebSocket.
      class Client
        # @param url [String, nil] optional override endpoint for tests.
        def initialize(url: nil)
          @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
          @started   = Concurrent::AtomicBoolean.new(false)
          cfg        = DhanHQ.configuration
          @url       = url || cfg.ws_order_url
        end

        # Starts the orders WebSocket connection.
        #
        # @return [DhanHQ::WS::Orders::Client] self
        def start
          return self if @started.true?

          @started.make_true
          @conn = Connection.new(url: @url) do |msg|
            emit(:update, msg) if msg&.dig(:Type) == "order_alert"
            emit(:raw, msg)
          end
          @conn.start
          DhanHQ::WS::Registry.register(self) if defined?(DhanHQ::WS::Registry)
          self
        end

        # Stops the connection and unregisters callbacks.
        #
        # @return [void]
        def stop
          return unless @started.true?

          @started.make_false
          @conn&.stop
          emit(:close, true)
          DhanHQ::WS::Registry.unregister(self) if defined?(DhanHQ::WS::Registry)
        end

        # Immediately closes the underlying WebSocket.
        #
        # @return [void]
        def disconnect!
          @conn&.disconnect!
        end

        # Subscribes a listener to an event.
        #
        # @param event [Symbol]
        # @yieldparam payload [Object]
        # @return [DhanHQ::WS::Orders::Client] self
        def on(event, &blk)
          @callbacks[event] << blk
          self
        end

        private

        # Broadcasts an event to all registered listeners.
        #
        # @param event [Symbol]
        # @param payload [Object]
        # @return [void]
        def emit(event, payload)
          list = begin
            @callbacks[event]
          rescue StandardError
            []
          end
          list.each { |cb| cb.call(payload) }
        end
      end
    end
  end
end
