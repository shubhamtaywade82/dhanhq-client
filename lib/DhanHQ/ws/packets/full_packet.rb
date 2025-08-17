# lib/dhanhq/ws/packets/full_packet.rb
require "bindata"
require_relative "market_depth_level"
module DhanHQ
  module WS
    module Packets
      class FullPacket < BinData::Record
        endian :little

        # Core Quote Data
        float :ltp # 4 bytes
        uint16 :last_trade_qty          # 2 bytes
        uint32 :ltt                     # 4 bytes (epoch in seconds)
        float :atp                      # 4 bytes
        uint32 :volume                  # 4 bytes
        int32 :total_sell_qty           # 4 bytes
        int32 :total_buy_qty            # 4 bytes

        # Open Interest & Extremes
        int32 :open_interest            # 4 bytes
        int32 :highest_oi               # 4 bytes (optional, F&O only)
        int32 :lowest_oi                # 4 bytes (optional, F&O only)

        # OHLC Values
        float :day_open                 # 4 bytes
        float :day_close                # 4 bytes
        float :day_high                 # 4 bytes
        float :day_low                  # 4 bytes

        # Market Depth (5 levels × 20 bytes)
        array :market_depth, initial_length: 5 do
          market_depth_level
        end
      end
    end
  end
end
