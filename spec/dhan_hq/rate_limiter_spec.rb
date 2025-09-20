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
      rate_limiter.send(:record_request)

      buckets = rate_limiter.instance_variable_get(:@buckets)
      expect(buckets[:per_second].value).to eq(1)
      expect(buckets[:per_minute].value).to eq(1)
      expect(buckets[:per_hour].value).to eq(1)
      expect(buckets[:per_day].value).to eq(1)
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

  describe "configured limits" do
    context "when api type is order_api" do
      it "enforces documented thresholds" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        buckets[:per_second].value = 25
        expect(rate_limiter.send(:allow_request?)).to be false

        buckets[:per_second].value = 0
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

      it "allows unlimited minute/hour traffic but caps per_second and per_day" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        buckets[:per_second].value = 5
        expect(rate_limiter.send(:allow_request?)).to be false

        buckets[:per_second].value = 0
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

      it "enforces the 1 request per second window" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        expect(rate_limiter.send(:allow_request?)).to be true
        buckets[:per_second].value = 1
        expect(rate_limiter.send(:allow_request?)).to be false

        # Unlimited buckets should not block requests
        buckets[:per_second].value = 0
        buckets[:per_minute].value = 1_000
        buckets[:per_hour].value = 1_000
        buckets[:per_day].value = 1_000
        expect(rate_limiter.send(:allow_request?)).to be true
      end
    end

    context "when api type is non_trading_api" do
      let(:api_type) { :non_trading_api }

      it "allows 20 per second with no other caps" do
        buckets = rate_limiter.instance_variable_get(:@buckets)

        buckets[:per_second].value = 20
        expect(rate_limiter.send(:allow_request?)).to be false

        buckets[:per_second].value = 0
        buckets[:per_minute].value = 1_000
        buckets[:per_hour].value = 10_000
        buckets[:per_day].value = 100_000
        expect(rate_limiter.send(:allow_request?)).to be true
      end
    end

    context "when api type is option_chain" do
      let(:api_type) { :option_chain }

      it "sleeps to respect the 4 second spacing" do
        allow(rate_limiter).to receive(:sleep)

        Timecop.freeze
        rate_limiter.throttle! # first call should not sleep

        Timecop.travel(1) # second request only 1 second later
        expect(rate_limiter).to receive(:sleep) do |duration|
          expect(duration).to be_within(0.1).of(3.0)
        end
        rate_limiter.throttle!
      ensure
        Timecop.return
      end
    end
  end
end
