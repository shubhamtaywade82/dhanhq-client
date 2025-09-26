# frozen_string_literal: true

require_relative "ws/client"
require_relative "ws/orders"

module DhanHQ
  # Namespace for the WebSocket streaming client helpers.
  #
  # The helpers provide a simple façade around {DhanHQ::WS::Client} so that
  # applications can start streaming market data with a single method call.
  module WS
    # Establishes a WebSocket connection and yields decoded ticks.
    #
    # @example Subscribe to ticker updates
    #   DhanHQ::WS.connect(mode: :ticker) do |tick|
    #     puts tick.inspect
    #   end
    #
    # @param mode [Symbol] Desired feed mode (:ticker, :quote, :full).
    # @yield [tick]
    # @yieldparam tick [Hash] A decoded tick emitted by the streaming API.
    # @return [DhanHQ::WS::Client] The underlying WebSocket client instance.
    def self.connect(mode: :ticker, &on_tick)
      Client.new(mode: mode).start.on(:tick, &on_tick)
    end

    # Disconnects every WebSocket client created in the current process.
    #
    # Useful when a long running script needs to ensure all connections are
    # closed (e.g., in signal handlers or +at_exit+ hooks).
    #
    # @return [void]
    def self.disconnect_all_local!
      Registry.stop_all
    end
  end
end
