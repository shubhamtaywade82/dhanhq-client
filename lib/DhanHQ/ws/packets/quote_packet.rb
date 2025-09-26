# frozen_string_literal: true

# lib/dhanhq/ws/packets/quote_packet.rb
require "bindata"
module DhanHQ
  module WS
    module Packets
      # Binary definition for quote snapshots emitted by the feed.
      class QuotePacket < BinData::Record
        endian :little

        float  :ltp # 4 bytes
        uint16 :last_trade_qty          # 2 bytes
        uint32 :ltt                     # 4 bytes
        float  :atp                     # 4 bytes
        uint32 :volume                  # 4 bytes
        int32  :total_sell_qty          # 4 bytes
        int32  :total_buy_qty           # 4 bytes
        float  :day_open                # 4 bytes
        float  :day_close               # 4 bytes
        float  :day_high                # 4 bytes
        float  :day_low                 # 4 bytes
      end
    end
  end
end
