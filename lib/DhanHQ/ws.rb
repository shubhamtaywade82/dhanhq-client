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

    # Cap on how many bytes of a frame get hex-dumped by {debug_frame}. A full
    # depth packet can run several KB; at tick frequency that floods the log
    # long before it adds diagnostic value beyond the first couple hundred
    # bytes (header + the first few fields is normally enough to spot a
    # parsing bug). The full frame size is always logged regardless of the cap.
    DEBUG_FRAME_MAX_BYTES = 256

    # Logs a raw inbound WebSocket frame as a hex dump when
    # +config.ws_debug+ (+DHAN_WS_DEBUG=true+) is enabled. A no-op otherwise --
    # the flag is checked before any hex encoding work, so there's no cost
    # when debug logging is off. Frames longer than {DEBUG_FRAME_MAX_BYTES}
    # are truncated in the dump, but the logged byte count is always the full
    # frame size.
    #
    # @param source [String] short tag identifying which connection the frame came from
    # @param data [String] raw frame bytes
    # @return [void]
    def self.debug_frame(source, data)
      return unless DhanHQ.configuration&.ws_debug?

      hex = data.byteslice(0, DEBUG_FRAME_MAX_BYTES).unpack1("H*")
      hex += "...truncated" if data.bytesize > DEBUG_FRAME_MAX_BYTES
      DhanHQ.logger&.debug("[DhanHQ::WS::#{source}] frame (#{data.bytesize} bytes): #{hex}")
    end
  end
end
