# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      # Disconnect payload (2 bytes). Your earlier code read signed big-endian; make it explicit.
      class DisconnectPacket < BinData::Record
        endian :big
        uint16 :code
      end
    end
  end
end
