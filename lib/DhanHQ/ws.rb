# frozen_string_literal: true

require_relative "ws/client"
require_relative "ws/orders"
require_relative "ws/market_depth"

module DhanHQ
  # Namespace for the WebSocket streaming client helpers.
  #
  # The helpers provide a simple façade around WebSocket clients so that
  # applications can start streaming data with single method calls.
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

    # Logs a raw inbound WebSocket frame as a hex dump when
    # +config.ws_debug+ (+DHAN_WS_DEBUG=true+) is enabled. A no-op otherwise --
    # the flag is checked before any hex encoding work, so there's no cost
    # when debug logging is off.
    #
    # @param source [String] short tag identifying which connection the frame came from
    # @param data [String] raw frame bytes
    # @return [void]
    def self.debug_frame(source, data)
      return unless DhanHQ.configuration&.ws_debug?

      DhanHQ.logger&.debug("[DhanHQ::WS::#{source}] frame (#{data.bytesize} bytes): #{data.unpack1("H*")}")
    end
  end
end
