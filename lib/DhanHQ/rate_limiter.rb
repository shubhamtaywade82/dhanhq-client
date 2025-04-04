# frozen_string_literal: true

require "concurrent"

module DhanHQ
  class RateLimiter
    RATE_LIMITS = {
      order_api: { per_second: 25, per_minute: 250, per_hour: 1000, per_day: 7000 },
      data_api: { per_second: 10, per_minute: 1000, per_hour: 5000, per_day: 10_000 },
      option_chain: { per_second: 1.0 / 3, per_minute: 20, per_hour: 600, per_day: 4800 },
      non_trading_api: { per_second: 20, per_minute: Float::INFINITY, per_hour: Float::INFINITY,
                         per_day: Float::INFINITY }
    }.freeze

    def initialize(api_type)
      @api_type = api_type
      @buckets = Concurrent::Hash.new
      @buckets[:last_request_time] = Time.at(0) if api_type == :option_chain
      initialize_buckets
      start_cleanup_threads
    end

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

    def initialize_buckets
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval] = Concurrent::AtomicFixnum.new(0)
      end
    end

    def allow_request?
      RATE_LIMITS[@api_type].all? do |interval, limit|
        @buckets[interval].value < limit
      end
    end

    def record_request
      RATE_LIMITS[@api_type].each_key do |interval|
        @buckets[interval].increment
      end
    end

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
