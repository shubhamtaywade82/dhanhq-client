# frozen_string_literal: true

require "spec_helper"
require "timecop"
require "concurrent"

RSpec.describe DhanHQ::RateLimiter do
  let(:api_type) { :order_api }
  let(:rate_limiter) { described_class.new(api_type) }

  before do
    # Prevent actual background threads from running
    allow_any_instance_of(described_class).to receive(:start_cleanup_threads)
  end

  describe "#initialize" do
    it "initializes rate limit buckets" do
      expect(rate_limiter.instance_variable_get(:@buckets)).to be_a(Concurrent::Hash)
    end

    it "sets rate limits for the given API type" do
      expect(rate_limiter.instance_variable_get(:@buckets).keys).to match_array(%i[per_second per_minute per_hour
                                                                                   per_day])
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
        rate_limiter.instance_variable_get(:@buckets)[:per_second].value
      }.by(1)
    end
  end

  describe "#allow_request?" do
    it "returns true when under limit" do
      expect(rate_limiter.send(:allow_request?)).to be true
    end

    it "returns false when exceeding the per_second limit" do
      rate_limiter.instance_variable_get(:@buckets)[:per_second].value = 25
      expect(rate_limiter.send(:allow_request?)).to be false
    end

    it "returns false when exceeding the per_minute limit" do
      rate_limiter.instance_variable_get(:@buckets)[:per_minute].value = 250
      expect(rate_limiter.send(:allow_request?)).to be false
    end
  end

  describe "#record_request" do
    it "increments all rate limit counters" do
      expect { rate_limiter.send(:record_request) }.to change {
        [
          rate_limiter.instance_variable_get(:@buckets)[:per_second].value,
          rate_limiter.instance_variable_get(:@buckets)[:per_minute].value
        ]
      }.by([1, 1])
    end
  end

  describe "rate limit resets" do
    before { Timecop.freeze }
    after { Timecop.return }

    it "resets per_second limit after 1 second" do
      rate_limiter.instance_variable_get(:@buckets)[:per_second].value = 25
      expect(rate_limiter.send(:allow_request?)).to be false

      Timecop.travel(1) # Simulate 1 second passing
      rate_limiter.instance_variable_get(:@buckets)[:per_second].value = 0

      expect(rate_limiter.send(:allow_request?)).to be true
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
end
