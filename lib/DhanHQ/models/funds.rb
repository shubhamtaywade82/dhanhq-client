# frozen_string_literal: true

module DhanHQ
  module Models
    class Funds < BaseModel
      class << self
        def margin_calculator(params)
          resource.margin_calculator(params)
        end

        def fund_limit
          resource.fund_limit
        end

        def resource
          @resource ||= DhanHQ::Resources::Funds.new
        end
      end
    end
  end
end
