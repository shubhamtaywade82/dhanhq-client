# frozen_string_literal: true

require "concurrent"
require_relative "connection"

module DhanHQ
  module WS
    module Orders
      class Client
        def initialize(url: nil)
          @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
          @started   = Concurrent::AtomicBoolean.new(false)
          cfg        = DhanHQ.configuration
          @url       = url || cfg.ws_order_url
        end

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

        def stop
          return unless @started.true?
          @started.make_false
          @conn&.stop
          emit(:close, true)
          DhanHQ::WS::Registry.unregister(self) if defined?(DhanHQ::WS::Registry)
        end

        def disconnect!
          @conn&.disconnect!
        end

        def on(event, &blk)
          @callbacks[event] << blk
          self
        end

        private

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
