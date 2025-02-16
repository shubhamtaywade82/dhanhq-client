# frozen_string_literal: true

require "debug"
require "dotenv/load"
require "DhanHQ"
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

  # Block real HTTP connections by default (except for VCR tests)
  WebMock.disable_net_connect!(allow_localhost: true)

  # Enforce WebMock for all tests EXCEPT those tagged with `vcr: true`
  config.before do |example|
    if example.metadata[:vcr]
      # Ensure VCR is active for tests using `vcr:`
      VCR.turn_on!
      WebMock.allow_net_connect! # Allow real API calls ONLY for VCR-tagged specs
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
  end
end
