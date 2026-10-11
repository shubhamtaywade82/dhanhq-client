# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Ticker payload (8 bytes): float32 ltp, uint32 ltt (epoch seconds) (both little-endian)
      class TickerPacket < BinData::Record
        endian :little
        float  :ltp       # 4 bytes
        uint32 :ltt       # 4 bytes
      end
    end
  end
end
