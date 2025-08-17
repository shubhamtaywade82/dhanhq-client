# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Ticker payload (8 bytes): float32 ltp, int32 ltt (both little-endian)
      class TickerPacket < BinData::Record
        endian :little
        float  :ltp       # 4 bytes
        int32  :ltt       # 4 bytes
      end
    end
  end
end
