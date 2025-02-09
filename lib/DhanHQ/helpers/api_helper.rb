# frozen_string_literal: true

module DhanHQ
  module APIHelper
    # Provide a reusable API client instance
    #
    # @return [DhanHQ::Client] The client instance
    def api_client
      @api_client ||= DhanHQ::Client.new
    end

    def success_response?(response)
      response[:status] == "success"
    end
  end
end
