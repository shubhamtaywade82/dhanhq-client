# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource for IP whitelist per API docs: GET /ip/getIP, POST /ip/setIP, PUT /ip/modifyIP.
    class IPSetup < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/ip"

      def current
        get("/getIP")
      end

      def set(ip:)
        post("/setIP", params: { ip: ip })
      end

      def update(ip:)
        put("/modifyIP", params: { ip: ip })
      end
    end
  end
end
