# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Blocks orders outside Indian market hours (9:15 AM - 3:30 PM IST).
      class MarketHours
        TIMEZONE_OFFSET = "+05:30"
        OPEN_HOUR = 9
        OPEN_MINUTE = 15
        CLOSE_HOUR = 15
        CLOSE_MINUTE = 30

        def self.run!(now: Time.now, **_unused)
          market_now = now.getlocal(TIMEZONE_OFFSET)
          return if market_open?(market_now)

          raise DhanHQ::RiskViolation, "Market is closed"
        end

        def self.market_open?(now)
          now.between?(market_open(now), market_close(now))
        end

        def self.market_open(now)
          Time.new(now.year, now.month, now.day, OPEN_HOUR, OPEN_MINUTE, 0, TIMEZONE_OFFSET)
        end

        def self.market_close(now)
          Time.new(now.year, now.month, now.day, CLOSE_HOUR, CLOSE_MINUTE, 0, TIMEZONE_OFFSET)
        end

        private_class_method :market_open?, :market_open, :market_close
      end
    end
  end
end
