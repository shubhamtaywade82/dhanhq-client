# frozen_string_literal: true

module DhanHQ
  module Models
    class OptionChain < BaseResource
      class << self
        def fetch(params)
          resource.fetch(params)
        end

        def expiry_list(params)
          resource.expiry_list(params)
        end

        def resource
          @resource ||= DhanHQ::Resources::OptionChain.new
        end
      end
    end
  end
end
