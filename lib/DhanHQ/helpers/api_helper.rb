# frozen_string_literal: true

module DhanHQ
  module APIHelper
    def api_client
      @api_client ||= DhanHQ::Client.new
    end

    def perform_request(http_method, path, params = {})
      response = api_client.send(http_method, path, params)
      build_from_response(response)
    end

    def success_response?(response)
      response[:status] == "success"
    end
  end
end
