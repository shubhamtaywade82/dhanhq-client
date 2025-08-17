# frozen_string_literal: true

module DhanHQ
  module WS
    module Packets
      # Layout not in public docs; keep raw bytes for now
      class IndexPacket
        attr_reader :raw

        def initialize(raw) = (@raw = raw)
      end
    end
  end
end
