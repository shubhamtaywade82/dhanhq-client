# frozen_string_literal: true

require "concurrent"

module DhanHQ
  # Coarse-grained in-memory throttler matching the platform rate limits.
  class RateLimiter
    # Per-interval thresholds keyed by API type, matching the published
    # DhanHQ rate-limit table (Order APIs: 10/sec, 100,000/day;
    # Data APIs: 5/sec, 7,000/day; Market Quote: 1/sec; Option Chain: 1 per 3 sec).
    RATE_LIMITS = {
      order_api: { per_second: 10, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: 100_000 },
      data_api: { per_second: 5, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: 7_000 },
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
    # Deliberately never sleeps while holding `mutex` — the background
    # cleanup threads (see {#start_cleanup_threads}) need that same mutex to
    # reset the per-minute/hour/day counters. Holding it across a sleep loop
    # here would starve those threads out forever once a counter maxes out
    # (observed: a sustained high-volume run pins the data_api per-day bucket
    # at its cap and the process never recovers).
    #
    # @return [void]
    def throttle!
      if @api_type == :option_chain
        wait_for_option_chain_slot
        return
      end

      wait_for_per_second_slot
      wait_for_bucket_capacity
      mutex.synchronize { record_request }
    end

    private

    def wait_for_option_chain_slot
      loop do
        sleep_time = mutex.synchronize { 3 - (Time.now - @buckets[:last_request_time]) }
        break if sleep_time <= 0

        puts "Sleeping for #{sleep_time.round(2)} seconds due to option_chain rate limit" if ENV["DHAN_DEBUG"] == "true"
        sleep(sleep_time)
      end
      mutex.synchronize { @buckets[:last_request_time] = Time.now }
    end

    def wait_for_per_second_slot
      per_second_limit = RATE_LIMITS[@api_type][:per_second]
      return unless per_second_limit && per_second_limit != Float::INFINITY

      loop do
        wait_time = mutex.synchronize do
          now = Time.now
          @request_times.reject! { |t| now - t >= 1.0 }
          break 0 if @request_times.size < per_second_limit

          1.0 - (now - @request_times.min)
        end
        break unless wait_time.positive?

        sleep(wait_time)
      end

      mutex.synchronize { @request_times << Time.now }
    end

    def wait_for_bucket_capacity
      loop do
        break if mutex.synchronize { allow_request? }

        sleep(0.1)
      end
    end

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
      @cleanup_threads = []
      @shutdown = Concurrent::AtomicBoolean.new(false)

      # Don't create per_second cleanup thread - we handle it with timestamps
      @cleanup_threads << Thread.new do
        loop do
          break if @shutdown.true?

          sleep(60)
          break if @shutdown.true?

          mutex.synchronize do
            @buckets[:per_minute]&.value = 0
          end
        end
      end

      @cleanup_threads << Thread.new do
        loop do
          break if @shutdown.true?

          sleep(3600)
          break if @shutdown.true?

          mutex.synchronize do
            @buckets[:per_hour]&.value = 0
          end
        end
      end

      @cleanup_threads << Thread.new do
        loop do
          break if @shutdown.true?

          sleep(86_400)
          break if @shutdown.true?

          mutex.synchronize do
            @buckets[:per_day]&.value = 0
          end
        end
      end
    end

    # Shuts down cleanup threads gracefully
    def shutdown
      return if @shutdown.true?

      @shutdown.make_true
      @cleanup_threads&.each do |thread|
        thread&.wakeup if thread&.alive?
        thread&.join(5) # Wait up to 5 seconds for thread to finish
      end
    end
  end
end
