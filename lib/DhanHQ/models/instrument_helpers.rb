# frozen_string_literal: true

module DhanHQ
  module Models
    # Helper module providing instance methods for Instrument objects
    # to access market feed, historical data, and option chain data.
    module InstrumentHelpers
      ##
      # Fetches last traded price (LTP) for this instrument.
      #
      # @return [Float, nil] Last traded price value, or nil if not available
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
      #   instrument.ltp  # => 26053.9
      def ltp
        params = build_market_feed_params
        response = DhanHQ::Models::MarketFeed.ltp(params)

        # Extract last_price from nested response structure
        # Response format: {"data" => {"EXCHANGE_SEGMENT" => {"security_id" => {"last_price" => value}}}, "status" => "success"}
        data = response[:data] || response["data"]
        return nil unless data

        segment_data = data[exchange_segment] || data[exchange_segment.to_sym]
        return nil unless segment_data

        security_data = segment_data[security_id] || segment_data[security_id.to_s]
        return nil unless security_data

        security_data[:last_price] || security_data["last_price"]
      end

      ##
      # Fetches OHLC (Open-High-Low-Close) data for this instrument.
      #
      # @return [Hash] Market feed OHLC response
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
      #   instrument.ohlc
      def ohlc
        params = build_market_feed_params
        DhanHQ::Models::MarketFeed.ohlc(params)
      end

      ##
      # Fetches full quote depth and analytics for this instrument.
      #
      # @return [Hash] Market feed quote response
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("NSE_FNO", "RELIANCE")
      #   instrument.quote
      def quote
        params = build_market_feed_params
        DhanHQ::Models::MarketFeed.quote(params)
      end

      ##
      # Fetches daily historical data for this instrument.
      #
      # @param from_date [String] Start date in YYYY-MM-DD format
      # @param to_date [String] End date in YYYY-MM-DD format
      # @param options [Hash] Additional options (e.g., expiry_code)
      # @return [Hash] Historical data with open, high, low, close, volume, timestamp arrays
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
      #   instrument.daily(from_date: "2024-01-01", to_date: "2024-01-31")
      def daily(from_date:, to_date:, **options)
        params = build_historical_data_params(from_date: from_date, to_date: to_date, **options)
        DhanHQ::Models::HistoricalData.daily(params)
      end

      ##
      # Fetches intraday historical data for this instrument.
      #
      # @param from_date [String] Start date in YYYY-MM-DD format
      # @param to_date [String] End date in YYYY-MM-DD format
      # @param interval [String] Time interval in minutes (1, 5, 15, 25, 60)
      # @param options [Hash] Additional options
      # @return [Hash] Historical data with open, high, low, close, volume, timestamp arrays
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
      #   instrument.intraday(from_date: "2024-09-11", to_date: "2024-09-15", interval: "15")
      def intraday(from_date:, to_date:, interval:, **options)
        params = build_historical_data_params(from_date: from_date, to_date: to_date, interval: interval, **options)
        DhanHQ::Models::HistoricalData.intraday(params)
      end

      ##
      # Fetches the expiry list for this instrument (option chain).
      #
      # @return [Array<String>] List of expiry dates in YYYY-MM-DD format
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("NSE_FNO", "NIFTY")
      #   expiries = instrument.expiry_list
      def expiry_list
        params = {
          underlying_scrip: security_id.to_i,
          underlying_seg: underlying_segment_for_options
        }
        DhanHQ::Models::OptionChain.fetch_expiry_list(params)
      end

      ##
      # Fetches the option chain for this instrument.
      #
      # @param expiry [String] Expiry date in YYYY-MM-DD format
      # @return [Hash] Option chain data
      # @example
      #   instrument = DhanHQ::Models::Instrument.find("NSE_FNO", "NIFTY")
      #   chain = instrument.option_chain(expiry: "2024-02-29")
      def option_chain(expiry:)
        params = {
          underlying_scrip: security_id.to_i,
          underlying_seg: underlying_segment_for_options,
          expiry: expiry
        }
        DhanHQ::Models::OptionChain.fetch(params)
      end

      private

      ##
      # Builds market feed params from instrument attributes.
      #
      # @return [Hash] Market feed params in format { "EXCHANGE_SEGMENT": [security_id] }
      def build_market_feed_params
        { exchange_segment => [security_id.to_i] }
      end

      ##
      # Builds historical data params from instrument attributes.
      #
      # @param from_date [String] Start date
      # @param to_date [String] End date
      # @param interval [String, nil] Time interval for intraday
      # @param options [Hash] Additional options
      # @return [Hash] Historical data params
      def build_historical_data_params(from_date:, to_date:, interval: nil, **options)
        params = {
          security_id: security_id,
          exchange_segment: exchange_segment,
          instrument: instrument,
          from_date: from_date,
          to_date: to_date
        }

        params[:interval] = interval if interval
        params.merge!(options) if options.any?

        params
      end

      ##
      # Determines the correct underlying segment for option chain APIs.
      # Index uses IDX_I; stocks map to NSE_FNO or BSE_FNO by exchange.
      def underlying_segment_for_options
        seg = exchange_segment.to_s
        ins = instrument.to_s

        # If already a valid underlying seg, return as-is
        return seg if %w[IDX_I NSE_FNO BSE_FNO MCX_FO].include?(seg)

        # Index detection by instrument kind or segment
        return "IDX_I" if ins == "INDEX" || seg == "IDX_I"

        # Map equities/stock-related segments to respective FNO
        return "NSE_FNO" if seg.start_with?("NSE")
        return "BSE_FNO" if seg.start_with?("BSE")

        # Fallback to IDX_I to avoid contract rejection
        "IDX_I"
      end
    end
  end
end
