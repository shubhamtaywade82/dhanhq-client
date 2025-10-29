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

    # Thread-safe shared rate limiters per API type
    @shared_limiters = Concurrent::Map.new
    @mutexes = Concurrent::Map.new

    class << self
      attr_reader :shared_limiters, :mutexes

      # Get or create a shared rate limiter instance for the given API type
      def for(api_type)
        @shared_limiters[api_type] ||= new(api_type)
      end
    end

    # Creates a rate limiter for a given API type.
    # Note: For proper rate limiting coordination, use RateLimiter.for(api_type) instead
    # of RateLimiter.new(api_type) to get a shared instance.
    #
    # @param api_type [Symbol] One of the keys from {RATE_LIMITS}.
    def initialize(api_type)
      @api_type = api_type
      @buckets = Concurrent::Hash.new
      @buckets[:last_request_time] = Time.at(0) if api_type == :option_chain
      # Track request timestamps for per-second limiting
      @request_times = []
      @window_start = Time.now
      initialize_buckets
      start_cleanup_threads
    end

    # Blocks until the current request is allowed by the configured limits.
    #
    # @return [void]
    def throttle!
      mutex.synchronize do
        if @api_type == :option_chain
          last_request_time = @buckets[:last_request_time]

          sleep_time = 3 - (Time.now - last_request_time)
          if sleep_time.positive?
            if ENV["DHAN_DEBUG"] == "true"
              puts "Sleeping for #{sleep_time.round(2)} seconds due to option_chain rate limit"
            end
            sleep(sleep_time)
          end

          @buckets[:last_request_time] = Time.now
          return
        end

        # For per-second limits, use timestamp-based sliding window
        per_second_limit = RATE_LIMITS[@api_type][:per_second]
        if per_second_limit && per_second_limit != Float::INFINITY
          now = Time.now
          # Remove requests older than 1 second
          @request_times.reject! { |t| now - t >= 1.0 }

          # Check if we've hit the per-second limit
          if @request_times.size >= per_second_limit
            # Calculate how long to wait until the oldest request is 1 second old
            oldest_time = @request_times.min
            wait_time = 1.0 - (now - oldest_time)

            if wait_time.positive?
              sleep(wait_time)
              # Recalculate after sleep
              now = Time.now
              @request_times.reject! { |t| now - t >= 1.0 }
            end
          end

          # Record this request time
          @request_times << Time.now
        end

        # Check other limits (per_minute, per_hour, per_day)
        loop do
          break if allow_request?

          sleep(0.1)
        end
        record_request
      end
    end

    private

    # Gets or creates a mutex for this API type for thread-safe throttling
    def mutex
      self.class.mutexes[@api_type] ||= Mutex.new
    end

    # Prepares the counters used for each interval in {RATE_LIMITS}.
    def initialize_buckets
      RATE_LIMITS[@api_type].each_key do |interval|
        # Skip per_second as we handle it with timestamps
        next if interval == :per_second

        @buckets[interval] = Concurrent::AtomicFixnum.new(0)
      end
    end

    # Determines whether a request can be made without exceeding limits.
    #
    # @return [Boolean]
    def allow_request?
      RATE_LIMITS[@api_type].all? do |interval, limit|
        # Skip per_second check as it's handled in throttle! with timestamps
        next true if interval == :per_second

        @buckets[interval].value < limit
      end
    end

    # Increments the counters for each time window once a request is made.
    def record_request
      RATE_LIMITS[@api_type].each_key do |interval|
        # Skip per_second as it's handled with timestamps
        next if interval == :per_second

        @buckets[interval].increment
      end
    end

    # Spawns background threads to reset counters after each interval elapses.
    def start_cleanup_threads
      # Don't create per_second cleanup thread - we handle it with timestamps
      Thread.new do
        loop do
          sleep(60)
          @buckets[:per_minute]&.value = 0
        end
      end
      Thread.new do
        loop do
          sleep(3600)
          @buckets[:per_hour]&.value = 0
        end
      end
      Thread.new do
        loop do
          sleep(86_400)
          @buckets[:per_day]&.value = 0
        end
      end
    end
  end
end
