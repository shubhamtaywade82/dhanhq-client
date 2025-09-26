# frozen_string_literal: true

require_relative "orders/client"

module DhanHQ
  module WS
    module Orders
      def self.connect(&on_update)
        Client.new.start.on(:update, &on_update)
      end
    end
  end
end
