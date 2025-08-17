# frozen_string_literal: true

require_relative "ws/client"

module DhanHQ
  module WS
    # One-liner convenience:
    # client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick.inspect }
    def self.connect(mode: :ticker, &on_tick)
      Client.new(mode: mode).start.on(:tick, &on_tick)
    end

    # Manual nuke switch for current process
    def self.disconnect_all_local!
      Registry.stop_all
    end
  end
end
