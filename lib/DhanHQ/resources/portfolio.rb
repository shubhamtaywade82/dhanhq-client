# frozen_string_literal: true

module DhanHQ
  module Resources
    class Portfolio < BaseAPI
      def holdings
        get("/holdings")
      end

      def positions
        get("/positions")
      end

      def convert_position(params)
        post("/positions/convert", params: params)
      end
    end
  end
end
