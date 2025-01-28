# frozen_string_literal: true

module DhanHQ
  module Models
    class HistoricalData < BaseResource
      class << self
        def daily(params)
          resource.daily(params)
        end

        def intraday(params)
          resource.intraday(params)
        end

        def resource
          @resource ||= DhanHQ::Resources::HistoricalData.new
        end
      end
    end
  end
end
