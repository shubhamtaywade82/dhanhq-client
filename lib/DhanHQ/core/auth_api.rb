# frozen_string_literal: true

require "faraday"

module DhanHQ
  # Faraday client for Dhan auth endpoints.
  #
  # This class intentionally lives at the top-level namespace so it autoloads
  # cleanly from `lib/DhanHQ/core/auth_api.rb` with Zeitwerk `collapse`.
  class AuthAPI
    BASE_URL = "https://auth.dhan.co"

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |faraday|
        faraday.request :url_encoded
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
