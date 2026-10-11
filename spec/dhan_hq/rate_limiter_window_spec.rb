# frozen_string_literal: true

require "timeout"

# Regression: an exhausted per-minute/hour/day bucket must reset. throttle! used
# to wait for the reset while holding the per-tier mutex the reset thread also
# needs, so the first caller past the cap blocked forever (and every later
# caller on that tier with it).
RSpec.describe DhanHQ::RateLimiter do
  before do
    stub_const("#{described_class}::RATE_LIMITS",
               test_api: { per_second: Float::INFINITY, per_minute: 2, per_hour: Float::INFINITY,
                           per_day: Float::INFINITY })
    stub_const("#{described_class}::RESET_INTERVALS", per_minute: 0.3, per_hour: 3600, per_day: 86_400)
    described_class.mutexes.delete(:test_api)
  end

  after { described_class.mutexes.delete(:test_api) }

  it "waits for the window to reset instead of deadlocking once a bucket is exhausted" do
    limiter = described_class.new(:test_api)
    2.times { limiter.throttle! }

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect { Timeout.timeout(3) { limiter.throttle! } }.not_to raise_error
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be >= 0.2
  ensure
    limiter&.send(:shutdown)
  end

  it "lets other threads into the limiter while one caller waits" do
    limiter = described_class.new(:test_api)
    2.times { limiter.throttle! }

    waiter = Thread.new { limiter.throttle! }
    sleep 0.05
    acquired = Timeout.timeout(1) { described_class.mutexes[:test_api].synchronize { true } }

    expect(acquired).to be(true)
    expect(waiter.join(3)).to be_truthy
  ensure
    limiter&.send(:shutdown)
  end
end
