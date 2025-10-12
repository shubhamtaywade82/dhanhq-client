# frozen_string_literal: true

require "concurrent"

module DhanHQ
  # WebSocket registry for managing connections and subscriptions
  module WS
    # Tracks the set of active WebSocket clients so they can be collectively
    # disconnected when required.
    class Registry
      @clients = []
      class << self
        # Registers a client instance with the registry.
        #
        # @param client [DhanHQ::WS::Client]
        # @return [void]
        def register(client)
          @clients << client unless @clients.include?(client)
        end

        # Removes a client from the registry.
        #
        # @param client [DhanHQ::WS::Client]
        # @return [void]
        def unregister(client)
          @clients.delete(client)
        end

        # Stops and removes all registered clients.
        #
        # @return [void]
        def stop_all
          @clients.dup.each do |c|
            c.stop
          rescue StandardError
          end
          @clients.clear
        end
      end
    end

    # convenience API
    def self.disconnect_all_local!
      Registry.stop_all
    end
  end
end
