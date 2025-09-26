# frozen_string_literal: true

require "concurrent"

module DhanHQ
  # Coarse-grained in-memory throttler matching the platform rate limits.
  class RateLimiter
    # Per-interval thresholds keyed by API type.
    RATE_LIMITS = {
      order_api: { per_second: 25, per_minute: 250, per_hour: 1000, per_day: 7000 },
      data_api: { per_second: 5, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: 100_000 },
      quote_api: { per_second: 1, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: Float::INFINITY },
      option_chain: { per_second: 1.0 / 3, per_minute: 20, per_hour: 600, per_day: 4800 },
      non_trading_api: { per_second: 20, per_minute: Float::INFINITY, per_hour: Float::INFINITY,
                         per_day: Float::INFINITY }
    }.freeze

    # Creates a rate limiter for a given API type.
    #
    # @param api_type [Symbol] One of the keys from {RATE_LIMITS}.
    def initialize(api_type)
      @api_type = api_type
      @buckets = Concurrent::Hash.new
      @buckets[:last_request_time] = Time.at(0) if api_type == :option_chain
      initialize_buckets
      start_cleanup_threads
    end

    # Blocks until the current request is allowed by the configured limits.
    #
    # @return [void]
    def throttle!
      if @api_type == :option_chain
        last_request_time = @buckets[:last_request_time]

        sleep_time = 4 - (Time.now - last_request_time)
        if sleep_time.positive?
          puts "Sleeping for #{sleep_time.round(2)} seconds due to option_chain rate limit"
          sleep(sleep_time)
        end

        @buckets[:last_request_time] = Time.now
        return
      end

      loop do
        break if allow_request?

        sleep(0.1)
      end
      record_request
    end

    private

    # Prepares the counters used for each interval in {RATE_LIMITS}.
    def initialize_buckets
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval] = Concurrent::AtomicFixnum.new(0)
      end
    end

    # Determines whether a request can be made without exceeding limits.
    #
    # @return [Boolean]
    def allow_request?
      RATE_LIMITS[@api_type].all? do |interval, limit|
        @buckets[interval].value < limit
      end
    end

    # Increments the counters for each time window once a request is made.
    def record_request
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval].increment
      end
    end

    # Spawns background threads to reset counters after each interval elapses.
    def start_cleanup_threads
      Thread.new do
        loop do
          sleep(1)
          @buckets[:per_second].value = 0
        end
      end
      Thread.new do
        loop do
          sleep(60)
          @buckets[:per_minute].value = 0
        end
      end
      Thread.new do
        loop do
          sleep(3600)
          @buckets[:per_hour].value = 0
        end
      end
      Thread.new do
        loop do
          sleep(86_400)
          @buckets[:per_day].value = 0
        end
      end
    end
  end
end
