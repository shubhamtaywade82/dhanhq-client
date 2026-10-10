# frozen_string_literal: true

require "concurrent"

module DhanHQ
  # WebSocket registry for managing connections and subscriptions
  module WS
    # Tracks the set of active WebSocket clients so they can be collectively
    # disconnected when required.
    class Registry
      @clients = []
      @mutex = Mutex.new
      class << self
        # Registers a client instance with the registry.
        #
        # @param client [DhanHQ::WS::Client]
        # @return [void]
        def register(client)
          @mutex.synchronize { @clients << client unless @clients.include?(client) }
        end

        # Removes a client from the registry.
        #
        # @param client [DhanHQ::WS::Client]
        # @return [void]
        def unregister(client)
          @mutex.synchronize { @clients.delete(client) }
        end

        # Stops and removes all registered clients.
        #
        # The client list is snapshotted and cleared under the mutex, but each
        # client is stopped *after* releasing it: `Client#stop` (market feed and
        # orders) calls {Registry.unregister} on itself, and Mutex is not
        # reentrant — stopping under the mutex would raise a recursive-locking
        # ThreadError that the per-client rescue would silently swallow, losing
        # the market feed's `emit(:close, true)` notification.
        #
        # @return [void]
        def stop_all
          clients = @mutex.synchronize do
            snapshot = @clients.dup
            @clients.clear
            snapshot
          end

          clients.each do |c|
            c.stop
          rescue StandardError => e
            DhanHQ.logger&.debug("[DhanHQ::WS::Registry] stop failed: #{e.class} #{e.message}")
          end
        end
      end
    end

    # convenience API
    def self.disconnect_all_local!
      Registry.stop_all
    end
  end
end
