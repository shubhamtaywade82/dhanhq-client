# frozen_string_literal: true

require "spec_helper"

# Safe-by-default settings for this release: request validation and the
# documented rate caps are opt-in, so live behaviour matches the previous release
# until a caller turns them on.
RSpec.describe DhanHQ::Configuration do
  subject(:config) { described_class.new(client_id: "1000000001", access_token: "test-token") }

  around do |example|
    keys = %w[DHAN_VALIDATE_REQUESTS DHAN_ENFORCE_RATE_LIMITS]
    saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  it "keeps request validation off by default" do
    expect(config.validate_requests?).to be false
  end

  it "keeps the documented rate caps off by default" do
    expect(config.enforce_rate_limits?).to be false
  end

  it "turns request validation on only when asked" do
    expect(described_class.new(validate_requests: true).validate_requests?).to be true
  end

  it "reads DHAN_ENFORCE_RATE_LIMITS from the environment" do
    ENV["DHAN_ENFORCE_RATE_LIMITS"] = "true"
    expect(described_class.new.enforce_rate_limits?).to be true
  end
end
