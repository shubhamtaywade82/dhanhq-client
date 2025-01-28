# frozen_string_literal: true

module DhanHQ
  module Resources
    class Funds < BaseAPI
      def margin_calculator(params)
        post("/margincalculator", params: params)
      end

      def fund_limit
        get("/fundlimit")
      end
    end
  end
end
