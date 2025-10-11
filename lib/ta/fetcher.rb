# frozen_string_literal: true

require "date"

module TA
  # Retrieves historical data from the DhanHQ API with retry semantics.
  class Fetcher
    def initialize(throttle_seconds: 3.0, max_retries: 3)
      @throttle_seconds = throttle_seconds.to_f
      @max_retries = max_retries.to_i
    end

    def intraday(params, interval)
      with_retries(":intraday/#{interval}") do
        DhanHQ::Models::HistoricalData.intraday(
          security_id: params[:security_id],
          exchange_segment: params[:exchange_segment],
          instrument: params[:instrument],
          interval: interval.to_s,
          from_date: params[:from_date],
          to_date: params[:to_date]
        )
      end
    end

    def intraday_windowed(params, interval)
      from_d = Date.parse(params[:from_date])
      to_d   = Date.parse(params[:to_date])
      max_span = 90
      return intraday(params, interval) if (to_d - from_d).to_i <= max_span

      merged = { "open" => [], "high" => [], "low" => [], "close" => [], "volume" => [], "timestamp" => [] }
      cursor = from_d
      while cursor <= to_d
        chunk_to = [cursor + max_span, to_d].min
        chunk_params = params.merge(from_date: cursor.strftime("%Y-%m-%d"), to_date: chunk_to.strftime("%Y-%m-%d"))
        part = intraday(chunk_params, interval)
        %w[open high low close volume timestamp].each do |k|
          ary = (part[k] || part[k.to_sym]) || []
          merged[k].concat(Array(ary))
        end
        cursor = chunk_to + 1
        sleep_with_jitter
      end
      merged
    end

    private

    def sleep_with_jitter(multiplier = 1.0)
      base = @throttle_seconds * multiplier
      jitter = rand * 0.3
      sleep(base + jitter)
    end

    def with_retries(_label)
      retries = 0
      begin
        yield
      rescue DhanHQ::RateLimitError => e
        retries += 1
        raise e if retries > @max_retries

        backoff = [5 * retries, 30].min
        sleep_with_jitter(backoff / 3.0)
        retry
      end
    end
  end
end
