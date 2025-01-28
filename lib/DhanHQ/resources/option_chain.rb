# frozen_string_literal: true

module DhanHQ
  module Resources
    class OptionChain < BaseAPI
      HTTP_PATH = "/optionchain"

      def fetch(params)
        post("", params: params)
      end

      def expiry_list(params)
        post("/expirylist", params: params)
      end
    end
  end
end
