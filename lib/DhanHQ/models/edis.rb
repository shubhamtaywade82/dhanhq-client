# frozen_string_literal: true

module DhanHQ
  module Models
    class Edis < BaseModel
      HTTP_PATH = "/v2/edis"

      class << self
        def resource
          @resource ||= DhanHQ::Resources::Edis.new
        end

        def form(params)
          resource.form(params)
        end

        def bulk_form(params)
          resource.bulk_form(params)
        end

        def tpin
          resource.tpin
        end

        def inquire(isin)
          resource.inquire(isin)
        end
      end

      def validation_contract
        nil
      end
    end
  end
end

