# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Depth delta payload (20 bytes): see Dhan spec
      class DepthDeltaPacket < BinData::Record
        endian :little
        uint32 :bid_quantity        # 4
        uint32 :ask_quantity        # 4
        uint16 :no_of_bid_orders    # 2
        uint16 :no_of_ask_orders    # 2
        float  :bid_price           # 4
        float  :ask_price           # 4
      end
    end
  end
end
