# frozen_string_literal: true

require "faraday"
require "json"

module DhanHQ
  # Helpers for Dhan authentication APIs.
  # The gem does not implement API key/secret consent flows or Partner consent;
  # use Dhan Web or your own OAuth flow to obtain tokens, then pass them via
  # configuration. This module supports refreshing web-generated tokens only.
  module Auth
    # Refreshes a web-generated access token (24h validity).
    # Calls POST /v2/RenewToken; expires the current token and returns a new one.
    # Only valid for tokens generated from Dhan Web (not API key flow).
    #
    # @param access_token [String] Current JWT from Dhan Web
    # @param client_id [String] Dhan client ID (dhanClientId)
    # @param base_url [String, nil] API base URL (default: DhanHQ.configuration.base_url)
    # @return [HashWithIndifferentAccess] Response with :access_token and :expiry_time (if present)
    # @raise [DhanHQ::Error] On HTTP or API error
    def self.renew_token(access_token, client_id, base_url: nil)
      base_url ||= DhanHQ.configuration&.base_url || Configuration::BASE_URL
      url = "#{base_url.chomp("/")}/RenewToken"

      conn = Faraday.new(url: url) do |c|
        c.request :json
        c.response :json, content_type: /\bjson$/
        c.adapter Faraday.default_adapter
      end

      response = conn.get("") do |req|
        req.headers["access-token"] = access_token
        req.headers["dhanClientId"] = client_id
        req.headers["Accept"] = "application/json"
      end

      unless response.success?
        body = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end
        error_message = body["errorMessage"] || body["message"] || response.body.to_s
        raise DhanHQ::InvalidAuthenticationError, "RenewToken failed: #{response.status} #{error_message}"
      end

      data = response.body
      data = JSON.parse(data) if data.is_a?(String)
      result = data.is_a?(Hash) ? data : {}
      result.with_indifferent_access
    end
  end
end
