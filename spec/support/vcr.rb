# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes" # Directory to store cassettes
  config.hook_into :webmock # Use WebMock to intercept HTTP requests
  config.configure_rspec_metadata! # Automatically tag RSpec examples with VCR metadata

  # Filter sensitive data from cassettes
  config.filter_sensitive_data("<DHAN_ACCESS_TOKEN>") do
    token = DhanHQ.configuration&.access_token
    token = ENV.fetch("DHAN_ACCESS_TOKEN", nil) if token.nil? || token.empty?
    token = ENV.fetch("ACCESS_TOKEN", nil) if token.nil? || token.empty?
    token.nil? || token.empty? ? "test_access_token" : token
  end

  config.filter_sensitive_data("<DHAN_CLIENT_ID>") do
    cid = DhanHQ.configuration&.client_id
    cid = ENV.fetch("DHAN_CLIENT_ID", nil) if cid.nil? || cid.empty?
    cid = ENV.fetch("CLIENT_ID", nil) if cid.nil? || cid.empty?
    cid.nil? || cid.empty? ? "test_client_id" : cid
  end

  # dhanClientId varies with the environment (local .env vs CI defaults), so matching on
  # it verbatim makes matches flaky. Normalize it out before comparing bodies.
  config.register_request_matcher(:body_ignoring_client_id) do |r1, r2|
    normalize = ->(body) { body.to_s.gsub(/"dhanClientId":\s*"[^"]*"/, '"dhanClientId":"FILTERED"') }
    normalize.call(r1.body) == normalize.call(r2.body)
  end

  # Allow overriding recording mode via ENV
  # Usage: VCR_RECORD=all bundle exec rspec
  config.default_cassette_options = {
    record: ENV.fetch("VCR_RECORD", :once).to_sym,
    match_requests_on: %i[method uri body_ignoring_client_id]
  }

  # Allow localhost connections (useful for Capybara)
  # config.allow_http_connections_when_no_cassette = false
  config.allow_http_connections_when_no_cassette = true
  config.ignore_hosts("127.0.0.1", "localhost")
end
