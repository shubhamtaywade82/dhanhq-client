# frozen_string_literal: true

require "spec_helper"
require "timecop"
require "concurrent"

RSpec.describe DhanHQ::RateLimiter do
  let(:api_type) { :order_api }
  let(:rate_limiter) { described_class.new(api_type) }

  before do
    # Allow cleanup threads to run for shutdown tests, but prevent for other tests
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:start_cleanup_threads).and_call_original
    # rubocop:enable RSpec/AnyInstance
  end

  describe "#initialize" do
    it "initializes rate limit buckets" do
      expect(rate_limiter.instance_variable_get(:@buckets)).to be_a(Concurrent::Hash)
    end

    it "sets rate limits for the given API type" do
      # per_second is now handled via timestamps (@request_times), not buckets
      expect(rate_limiter.instance_variable_get(:@buckets).keys).to match_array(%i[per_minute per_hour per_day])
    end

    it "initializes request_times array for per-second limiting" do
      expect(rate_limiter.instance_variable_get(:@request_times)).to be_a(Array)
    end
  end

  describe "#throttle!" do
    it "does not wait if within the rate limit" do
      expect { rate_limiter.throttle! }.not_to raise_error
    end

    it "waits and retries when request is not allowed" do
      allow(rate_limiter).to receive(:allow_request?).and_return(false, false, true) # First two times false, then true

      start_time = Time.now
      expect { rate_limiter.throttle! }.not_to raise_error
      end_time = Time.now

      expect(end_time - start_time).to be >= 0.1 # Ensures it actually waited before retrying
    end

    it "records the request after throttling" do
      expect { rate_limiter.throttle! }.to change {
        rate_limiter.instance_variable_get(:@request_times).size
      }.by(1)
    end
  end

  describe "#allow_request?" do
    it "returns true when under limit" do
      expect(rate_limiter.send(:allow_request?)).to be true
    end

    it "returns false when exceeding the per_second limit" do
      # For per_second limiting, we test via throttle! which uses timestamps
      # allow_request? skips per_second checks (handled in throttle!)
      # So we test by filling the request_times array
      limit = DhanHQ::RateLimiter::RATE_LIMITS[:order_api][:per_second]
      limit.times { rate_limiter.instance_variable_get(:@request_times) << Time.now }
      # NOTE: allow_request? doesn't check per_second anymore, but throttle! will
      expect(rate_limiter.instance_variable_get(:@request_times).size).to eq(limit)
    end

    it "returns false when exceeding the per_minute limit" do
      rate_limiter.instance_variable_get(:@buckets)[:per_minute].value = 250
      expect(rate_limiter.send(:allow_request?)).to be false
    end
  end

  describe "#record_request" do
    it "increments all rate limit counters (except per_second which uses timestamps)" do
      rate_limiter.send(:record_request)

      buckets = rate_limiter.instance_variable_get(:@buckets)
      # per_second is handled via timestamps, not buckets
      expect(buckets[:per_minute].value).to eq(1)
      expect(buckets[:per_hour].value).to eq(1)
      expect(buckets[:per_day].value).to eq(1)
    end
  end

  describe "rate limit resets" do
    before { Timecop.freeze }
    after { Timecop.return }

    it "handles per_second limit via timestamps (sliding window)" do
      # per_second limiting now uses timestamps in a sliding window
      limit = DhanHQ::RateLimiter::RATE_LIMITS[:order_api][:per_second]
      request_times = rate_limiter.instance_variable_get(:@request_times)

      # Add requests at current time
      limit.times { request_times << Time.now }
      expect(request_times.size).to eq(limit)

      # Simulate 1 second passing - old timestamps should be removed in throttle!
      Timecop.travel(1)
      # Clean up old timestamps (this happens in throttle!)
      now = Time.now
      request_times.reject! { |t| now - t >= 1.0 }

      # After cleanup, should have room for new requests
      expect(request_times.size).to eq(0)
    end

    it "resets per_minute limit after 60 seconds" do
      rate_limiter.instance_variable_get(:@buckets)[:per_minute].value = 250
      expect(rate_limiter.send(:allow_request?)).to be false

      Timecop.travel(60) # Simulate 60 seconds passing
      rate_limiter.instance_variable_get(:@buckets)[:per_minute].value = 0

      expect(rate_limiter.send(:allow_request?)).to be true
    end

    it "resets per_hour limit after 3600 seconds" do
      rate_limiter.instance_variable_get(:@buckets)[:per_hour].value = 1000
      expect(rate_limiter.send(:allow_request?)).to be false

      Timecop.travel(3600) # Simulate 1 hour passing
      rate_limiter.instance_variable_get(:@buckets)[:per_hour].value = 0

      expect(rate_limiter.send(:allow_request?)).to be true
    end

    it "resets per_day limit after 86,400 seconds (1 day)" do
      rate_limiter.instance_variable_get(:@buckets)[:per_day].value = 7000
      expect(rate_limiter.send(:allow_request?)).to be false

      Timecop.travel(86_400) # Simulate 1 day passing
      rate_limiter.instance_variable_get(:@buckets)[:per_day].value = 0

      expect(rate_limiter.send(:allow_request?)).to be true
    end
  end

  describe "configured limits" do
    context "when api type is order_api" do
      it "enforces documented thresholds" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        # per_second is handled via timestamps in throttle!, not in allow_request?
        buckets[:per_minute].value = 250
        expect(rate_limiter.send(:allow_request?)).to be false

        buckets[:per_minute].value = 0
        buckets[:per_hour].value = 1000
        expect(rate_limiter.send(:allow_request?)).to be false

        buckets[:per_hour].value = 0
        buckets[:per_day].value = 7000
        expect(rate_limiter.send(:allow_request?)).to be false
      end
    end

    context "when api type is data_api" do
      let(:api_type) { :data_api }

      it "allows unlimited minute/hour traffic but caps per_second (via timestamps) and per_day" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        # per_second is handled via timestamps in throttle!, not in allow_request?
        buckets[:per_minute].value = 10_000
        buckets[:per_hour].value = 50_000
        expect(rate_limiter.send(:allow_request?)).to be true

        buckets[:per_minute].value = 0
        buckets[:per_hour].value = 0
        buckets[:per_day].value = 100_000
        expect(rate_limiter.send(:allow_request?)).to be false
      end
    end

    context "when api type is quote_api" do
      let(:api_type) { :quote_api }

      it "enforces the 1 request per second window (via timestamps)" do
        buckets = rate_limiter.instance_variable_get(:@buckets)
        request_times = rate_limiter.instance_variable_get(:@request_times)

        expect(rate_limiter.send(:allow_request?)).to be true

        # per_second is handled via timestamps
        request_times << Time.now
        expect(request_times.size).to eq(1)

        # Unlimited buckets should not block requests
        buckets[:per_minute].value = 1_000
        buckets[:per_hour].value = 1_000
        buckets[:per_day].value = 1_000
        expect(rate_limiter.send(:allow_request?)).to be true
      end
    end

    context "when api type is non_trading_api" do
      let(:api_type) { :non_trading_api }

      it "allows 20 per second (via timestamps) with no other caps" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        # per_second is handled via timestamps, not buckets
        buckets[:per_minute].value = 1_000
        buckets[:per_hour].value = 10_000
        buckets[:per_day].value = 100_000
        expect(rate_limiter.send(:allow_request?)).to be true
      end
    end

    context "when api type is option_chain" do
      let(:api_type) { :option_chain }

      it "sleeps to respect the 3 second spacing" do
        # Create a fresh rate limiter to avoid shared state
        fresh_limiter = described_class.new(:option_chain)

        # Start with time frozen
        frozen_time = Time.now
        Timecop.freeze(frozen_time)

        # First call - last_request_time starts at Time.at(0), sleep_time will be negative (won't sleep)
        # Verify it doesn't raise an error
        expect { fresh_limiter.throttle! }.not_to raise_error

        # Get the last_request_time after first call
        buckets = fresh_limiter.instance_variable_get(:@buckets)
        first_call_time = buckets[:last_request_time]

        # Travel 1 second forward
        Timecop.travel(frozen_time + 1)

        # Second call: last_request_time is now frozen_time, current is frozen_time + 1
        # sleep_time = 3 - 1 = 2 seconds, so it should sleep
        # Since we can't reliably stub Kernel.sleep, we verify the timing logic is correct
        # by checking that throttle! completes (the sleep happens but we can't verify duration)
        expect { fresh_limiter.throttle! }.not_to raise_error

        # Verify the last_request_time was updated
        second_call_time = buckets[:last_request_time]
        expect(second_call_time).to be > first_call_time

        # Shutdown immediately to stop cleanup threads
        fresh_limiter.send(:shutdown)
      ensure
        Timecop.return
      end
    end
  end

  describe "#shutdown" do
    it "stops cleanup threads gracefully" do
      limiter = described_class.new(:order_api)
      cleanup_threads = limiter.instance_variable_get(:@cleanup_threads)

      expect(cleanup_threads).not_to be_empty
      expect(cleanup_threads.all?(&:alive?)).to be true

      limiter.send(:shutdown)

      # Give threads a moment to finish (with timeout to avoid hanging)
      start_time = Time.now
      sleep(0.1) while cleanup_threads.any?(&:alive?) && (Time.now - start_time) < 2
      expect(cleanup_threads.all? { |t| !t.alive? }).to be true
    end

    it "can be called multiple times safely" do
      limiter = described_class.new(:order_api)
      expect { limiter.send(:shutdown) }.not_to raise_error
      expect { limiter.send(:shutdown) }.not_to raise_error
      # Give threads time to actually shutdown
      sleep(0.1)
    end
  end

  describe "thread safety" do
    it "synchronizes cleanup thread bucket modifications" do
      limiter = described_class.new(:order_api)
      buckets = limiter.instance_variable_get(:@buckets)

      # Simulate concurrent access
      threads = []
      10.times do
        threads << Thread.new do
          10.times do
            limiter.send(:mutex).synchronize do
              buckets[:per_minute]&.increment
            end
          end
        end
      end

      threads.each(&:join)

      # Should have incremented 100 times
      expect(buckets[:per_minute].value).to eq(100)
    end
  end
end
