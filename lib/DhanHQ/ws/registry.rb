# frozen_string_literal: true

require "concurrent"

module DhanHQ
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
          @clients.dup.each do |client|
            client.stop
          rescue StandardError => e
            DhanHQ.logger&.warn("[DhanHQ::WS] failed to stop client #{client.class}: #{e.message}")
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
