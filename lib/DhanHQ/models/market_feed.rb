# frozen_string_literal: true

module DhanHQ
  module Models
    class MarketFeed < BaseModel
      class << self
        def ltp(params)
          resource.ltp(params)
        end

        def ohlc(params)
          resource.ohlc(params)
        end

        def quote(params)
          resource.quote(params)
        end

        def resource
          @resource ||= DhanHQ::Resources::MarketFeed.new
        end
      end
    end
  end
end
