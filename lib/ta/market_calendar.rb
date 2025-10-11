# frozen_string_literal: true

require "date"

module TA
  # Supplies helpers for working with trading-day calendars.
  module MarketCalendar
    MARKET_HOLIDAYS = [
      Date.new(2025, 8, 15),
      Date.new(2025, 10, 2),
      Date.new(2025, 8, 27)
    ].freeze

    def self.weekday?(date)
      w = date.wday
      w.between?(1, 5)
    end

    def self.trading_day?(date)
      weekday?(date) && !MARKET_HOLIDAYS.include?(date)
    end

    def self.last_trading_day(from: Date.today)
      d = from
      d -= 1 until trading_day?(d)
      d
    end

    def self.prev_trading_day(from: Date.today)
      d = from - 1
      d -= 1 until trading_day?(d)
      d
    end

    def self.today_or_last_trading_day
      trading_day?(Date.today) ? Date.today : last_trading_day(from: Date.today)
    end

    def self.trading_days_ago(date, days_back)
      raise ArgumentError, "n must be >= 0" if days_back.to_i.negative?

      d = trading_day?(date) ? date : today_or_last_trading_day
      count = 0
      while count < days_back
        d = prev_trading_day(from: d)
        count += 1
      end
      d
    end
  end
end
