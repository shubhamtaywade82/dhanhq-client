# frozen_string_literal: true

require_relative "orders/client"

module DhanHQ
  module WS
    module Orders
      def self.connect(&)
        Client.new.start.on(:update, &)
      end
    end
  end
end
