# frozen_string_literal: true

module DhanHQ
  module Resources
    class KillSwitch < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/killswitch"

      def update(params)
        post("", params: params)
      end
    end
  end
end

