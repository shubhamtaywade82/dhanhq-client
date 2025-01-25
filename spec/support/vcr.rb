# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes" # Directory to store cassettes
  config.hook_into :webmock # Use WebMock to intercept HTTP requests
  config.configure_rspec_metadata! # Automatically tag RSpec examples with VCR metadata

  # Filter sensitive data from cassettes
  config.filter_sensitive_data("<ACCESS_TOKEN>") { DhanHQ.configuration.access_token }
  config.filter_sensitive_data("<CLIENT_ID>") { DhanHQ.configuration.client_id }
  config.filter_sensitive_data("<CLIENT_ID>") { ENV.fetch("CLIENT_ID", nil) }

  # Allow localhost connections (useful for Capybara)
  config.allow_http_connections_when_no_cassette = false
  config.ignore_hosts("127.0.0.1", "localhost")
end
