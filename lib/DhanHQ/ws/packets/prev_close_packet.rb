# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Prev Close payload (8 bytes): float32 prev_close, int32 oi_prev (little-endian)
      class PrevClosePacket < BinData::Record
        endian :little
        float :prev_close    # 4 bytes
        int32 :oi_prev       # 4 bytes
      end
    end
  end
end
