# frozen_string_literal: true

require "concurrent"

module DhanHQ
  # Coarse-grained in-memory throttler matching the platform rate limits.
  class RateLimiter
    # Per-interval thresholds keyed by API type.
    #
    # Dhan's two official doc sites disagree on the daily caps:
    #   dhanhq.co/docs/v2   — Order 10/s, 250/min, 1,000/hr, 7,000/day;  Data 5/s, 100,000/day
    #   docs.dhanhq.co      — Order 10/s, 100,000/day;                   Data 5/s, 7,000/day
    # Exceeding a real cap risks DH-904/805 and connection blocking, so every
    # tier takes the stricter value from either source: Order 10/s, 250/min,
    # 1,000/hr, 7,000/day; Data 5/s, 7,000/day. Market Quote 1/s; Option Chain
    # 1 per 3 s.
    # Global Stocks shares the order-API limits on its own tier so it can be
    # routed independently (it always stays on the production host).
    RATE_LIMITS = {
      order_api: { per_second: 10, per_minute: 250, per_hour: 1_000, per_day: 7_000 },
      global_stocks_api: { per_second: 10, per_minute: 250, per_hour: 1_000, per_day: 7_000 },
      data_api: { per_second: 5, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: 7_000 },
      quote_api: { per_second: 1, per_minute: Float::INFINITY, per_hour: Float::INFINITY, per_day: Float::INFINITY },
      option_chain: { per_second: 1.0 / 3, per_minute: 20, per_hour: 600, per_day: 4800 },
      non_trading_api: { per_second: 20, per_minute: Float::INFINITY, per_hour: Float::INFINITY,
                         per_day: Float::INFINITY }
    }.freeze

    # Seconds to wait between counter resets, per interval.
    RESET_INTERVALS = { per_minute: 60, per_hour: 3600, per_day: 86_400 }.freeze

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
      # Admission is decided under the per-tier mutex, but every wait happens
      # outside it: the reset threads take the same mutex to clear exhausted
      # minute/hour/day buckets, so sleeping while holding it deadlocked the
      # first caller past a cap (and every later caller on that tier).
      loop do
        wait = mutex.synchronize { try_acquire }
        return if wait.nil?

        sleep(wait)
      end
    end

    # NOTE: @request_times is only touched inside #try_acquire, which runs under
    # the per-tier mutex, so the plain Array needs no synchronization of its own.

    private

    # Admits one request if every window allows it. Must be called with the
    # per-tier mutex held; never sleeps.
    #
    # @return [Float, nil] nil when admitted (and recorded); otherwise the
    #   seconds to wait, outside the mutex, before trying again.
    def try_acquire
      return option_chain_wait if @api_type == :option_chain

      now = Time.now
      per_second_limit = RATE_LIMITS[@api_type][:per_second]
      finite_per_second = per_second_limit && per_second_limit != Float::INFINITY
      if finite_per_second
        @request_times.reject! { |t| now - t >= 1.0 }
        return [1.0 - (now - @request_times.min), 0.01].max if @request_times.size >= per_second_limit
      end
      return 0.1 unless allow_request?

      @request_times << now if finite_per_second
      record_request
      nil
    end

    # Option chain: one request per 3 seconds (the documented limit). Its
    # minute/hour/day entries in RATE_LIMITS have never been counted, and
    # enforcing the 600/hour cap would stall 3-second polling for half of every
    # hour, so they stay unenforced.
    def option_chain_wait
      remaining = 3 - (Time.now - @buckets[:last_request_time])
      if remaining.positive?
        DhanHQ.logger&.debug("[DhanHQ::RateLimiter] Waiting #{remaining.round(2)}s (option_chain limit)")
        return remaining
      end

      @buckets[:last_request_time] = Time.now
      nil
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

    # Spawns one reset thread per interval whose limit is finite. Intervals whose
    # limit is Float::INFINITY never block, so resetting them is a no-op and no
    # thread is created (quote and non-trading tiers end up with zero threads).
    # Threads die with the process; #shutdown exists for explicit teardown.
    def start_cleanup_threads
      @cleanup_threads = []
      @shutdown = Concurrent::AtomicBoolean.new(false)

      RESET_INTERVALS.each do |interval, seconds|
        limit = RATE_LIMITS[@api_type][interval]
        next if limit.nil? || limit >= Float::INFINITY

        @cleanup_threads << Thread.new do
          loop do
            break if @shutdown.true?

            sleep(seconds)
            break if @shutdown.true?

            mutex.synchronize do
              @buckets[interval]&.value = 0
            end
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
