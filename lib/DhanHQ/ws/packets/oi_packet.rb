# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # OI payload (4 bytes): int32 little-endian
      class OiPacket < BinData::Record
        endian :little
        int32  :open_interest
      end
    end
  end
end
