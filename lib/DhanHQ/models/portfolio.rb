# frozen_string_literal: true

module DhanHQ
  module Models
    class Portfolio < BaseResource
      class << self
        def holdings
          resource.holdings
        end

        def positions
          resource.positions
        end

        def convert_position(params)
          resource.convert_position(params)
        end

        def resource
          @resource ||= DhanHQ::Resources::Portfolio.new
        end
      end
    end
  end
end
