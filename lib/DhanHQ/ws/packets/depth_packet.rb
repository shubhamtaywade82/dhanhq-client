# frozen_string_literal: true

require "bindata"
require_relative "market_depth_level"

module DhanHQ
  module WS
    module Packets
      # 5-level market depth packet payload (response code 3, 104-byte body):
      # LTP followed by five 20-byte depth levels, all little-endian.
      class DepthPacket < BinData::Record
        endian :little

        float :ltp # 4 bytes
        array :market_depth, initial_length: 5 do
          market_depth_level
        end
      end
    end
  end
end
