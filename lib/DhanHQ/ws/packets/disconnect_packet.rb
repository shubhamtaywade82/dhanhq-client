# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Disconnect payload (2 bytes): uint16 LITTLE-endian code (805–809).
      #
      # 805 connection limit · 806 not subscribed · 807 token expired ·
      # 808 auth failed · 809 token invalid.
      class DisconnectPacket < BinData::Record
        endian :little
        uint16 :code
      end
    end
  end
end
