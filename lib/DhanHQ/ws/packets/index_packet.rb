# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Index packet payload (24 bytes, little-endian) — response code 1.
      #
      # Index instruments (IDX_I segment) stream this packet instead of the
      # ticker/quote packets used by tradable instruments:
      #
      #   0:  float32 latest price
      #   4:  float32 open
      #   8:  float32 close (populated only after market close)
      #   12: float32 high
      #   16: float32 low
      #   20: int32   last update time (epoch seconds)
      class IndexPacket < BinData::Record
        endian :little

        float :latest
        float :open
        float :close
        float :high
        float :low
        uint32 :update_time
      end
    end
  end
end
