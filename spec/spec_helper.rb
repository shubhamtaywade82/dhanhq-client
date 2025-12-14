# frozen_string_literal: true

if ENV["SIMPLECOV"] == "true" || ENV["COVERAGE"] == "true"
  require "simplecov"

  SimpleCov.start do
    enable_coverage :branch
    track_files "lib/DhanHQ/models/**/*.rb"
    add_filter "/spec/"
    add_filter "/tmp/"
    add_filter do |source_file|
      !source_file.filename.include?("/lib/DhanHQ/models/")
    end
  end
end

require "debug"
require "dotenv/load"
require "dhan_hq"
require "webmock/rspec"

require_relative "support/vcr"
Dir[File.join(__dir__, "support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Store original ENV values to restore after tests
  original_env = {}

  config.before(:suite) do
    # Save original ENV values
    original_env[:client_id] = ENV.fetch("CLIENT_ID", nil)
    original_env[:access_token] = ENV.fetch("ACCESS_TOKEN", nil)
  end

  config.after(:suite) do
    # Restore original ENV values at the end
    if original_env[:client_id]
      ENV["CLIENT_ID"] = original_env[:client_id]
    else
      ENV.delete("CLIENT_ID")
    end
    if original_env[:access_token]
      ENV["ACCESS_TOKEN"] = original_env[:access_token]
    else
      ENV.delete("ACCESS_TOKEN")
    end
  end

  # Block real HTTP connections by default (except for VCR tests)
  WebMock.disable_net_connect!(allow_localhost: true)

  # Enforce WebMock for all tests EXCEPT those tagged with `vcr: true`
  config.before do |example|
    if example.metadata[:vcr]
      # Ensure VCR is active for tests using `vcr:`
      VCR.turn_on!
      WebMock.allow_net_connect! # Allow real API calls ONLY for VCR-tagged specs
      # Ensure ENV variables are set for VCR tests (they need auth even with cassettes)
      # Use original values if available, otherwise use test defaults
      ENV["CLIENT_ID"] ||= original_env[:client_id] || "test_client_id"
      ENV["ACCESS_TOKEN"] ||= original_env[:access_token] || "test_access_token"
      DhanHQ.configure_with_env
    else
      # Ensure all other tests use WebMock instead of VCR
      VCR.eject_cassette if VCR.current_cassette
      VCR.turn_off!
      WebMock.disable_net_connect!(allow_localhost: true)
    end
  end

  config.after do |example|
    # Reset VCR state after running any `vcr:` test
    VCR.eject_cassette if example.metadata[:vcr]
    VCR.turn_on!

    # Restore ENV variables after tests that might have deleted them
    # This prevents test pollution while allowing tests to modify ENV for their own purposes
    # Only restore if ENV was deleted (nil) and we have original or default values
    if ENV["CLIENT_ID"].nil? && (original_env[:client_id] || example.metadata[:vcr])
      ENV["CLIENT_ID"] = original_env[:client_id] || "test_client_id"
    end

    if ENV["ACCESS_TOKEN"].nil? && (original_env[:access_token] || example.metadata[:vcr])
      ENV["ACCESS_TOKEN"] = original_env[:access_token] || "test_access_token"
    end
  end
end
