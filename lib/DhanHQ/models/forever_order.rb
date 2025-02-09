# frozen_string_literal: true

module DhanHQ
  module Models
    class ForeverOrder < BaseModel
      class << self
        # Access the API resource for orders
        #
        # @return [DhanHQ::Resources::Orders]
        def resource
          @resource ||= DhanHQ::Resources::ForeverOrders.new
        end
      end
    end
  end
end
