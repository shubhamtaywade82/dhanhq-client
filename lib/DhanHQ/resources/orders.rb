# frozen_string_literal: true

module DhanHQ
  module Resources
    class Orders < BaseAPI
      HTTP_PATH = "/orders"

      def slicing(params)
        post("/slicing", params: params)
      end

      def by_correlation_id(correlation_id)
        get("/external/#{correlation_id}")
      end
    end
  end
end
