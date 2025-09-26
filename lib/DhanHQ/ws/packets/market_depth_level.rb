# frozen_string_literal: true

# lib/dhanhq/ws/packets/market_depth_level.rb
require "bindata"
module DhanHQ
  module WS
    module Packets
      # Binary representation of a single depth level in the feed.
      class MarketDepthLevel < BinData::Record
        endian :little

        uint32 :bid_quantity           # 4 bytes
        uint32 :ask_quantity           # 4 bytes
        uint16 :no_of_bid_orders       # 2 bytes
        uint16 :no_of_ask_orders       # 2 bytes
        float  :bid_price              # 4 bytes
        float  :ask_price              # 4 bytes
      end
    end
  end
end
