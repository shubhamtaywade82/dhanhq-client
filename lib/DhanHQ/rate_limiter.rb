# frozen_string_literal: true

require "concurrent"

module DhanHQ
  class RateLimiter
    RATE_LIMITS = {
      order_api: { per_second: 25, per_minute: 250, per_hour: 1000, per_day: 7000 },
      data_api: { per_second: 10, per_minute: 1000, per_hour: 5000, per_day: 10_000 },
      non_trading_api: { per_second: 20, per_minute: Float::INFINITY, per_hour: Float::INFINITY,
                         per_day: Float::INFINITY }
    }.freeze

    def initialize(api_type)
      @api_type = api_type
      @buckets = Concurrent::Hash.new
      initialize_buckets
      start_cleanup_threads
    end

    # 🌟 **Throttle before making a request**
    def throttle!
      loop do
        break if allow_request?

        sleep(0.1) # Wait for a small time before retrying
      end
      record_request
    end

    private

    # Initialize rate limit counters
    def initialize_buckets
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval] = Concurrent::AtomicFixnum.new(0)
      end
    end

    # 🌟 **Check if a request can be allowed**
    def allow_request?
      RATE_LIMITS[@api_type].all? do |interval, limit|
        @buckets[interval].value < limit
      end
    end

    # 🌟 **Record the API request usage**
    def record_request
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval].increment
      end
    end

    # 🌟 **Reset buckets at specific intervals**
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
