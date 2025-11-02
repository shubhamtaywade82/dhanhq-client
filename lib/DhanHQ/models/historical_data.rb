# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model for fetching historical candle data (OHLC) for desired instruments across segments and exchanges.
    #
    # This API provides historical price data in the form of candlestick data with timestamp, open, high, low,
    # close, and volume information. Data is available in two formats:
    # - **Daily**: Daily candle data available back to the date of instrument inception
    # - **Intraday**: Minute-level candle data (1, 5, 15, 25, 60 minutes) available for the last 5 years
    #
    # @example Fetch daily historical data
    #   data = DhanHQ::Models::HistoricalData.daily(
    #     security_id: "1333",
    #     exchange_segment: "NSE_EQ",
    #     instrument: "EQUITY",
    #     from_date: "2022-01-08",
    #     to_date: "2022-02-08"
    #   )
    #   puts "First day close: #{data[:close].first}"
    #
    # @example Fetch intraday historical data
    #   data = DhanHQ::Models::HistoricalData.intraday(
    #     security_id: "1333",
    #     exchange_segment: "NSE_EQ",
    #     instrument: "EQUITY",
    #     interval: "15",
    #     from_date: "2024-09-11",
    #     to_date: "2024-09-15"
    #   )
    #   puts "Total candles: #{data[:open].size}"
    #
    # @note For intraday data, only 90 days of data can be polled at once for any time interval.
    #   It is recommended to store this data locally for day-to-day analysis.
    #
    class HistoricalData < BaseModel
      # Base path for historical data endpoints.
      HTTP_PATH = "/v2/charts"

      class << self
        ##
        # Provides a shared instance of the HistoricalData resource.
        #
        # @return [DhanHQ::Resources::HistoricalData] The HistoricalData resource client instance
        def resource
          @resource ||= DhanHQ::Resources::HistoricalData.new
        end

        ##
        # Fetches daily OHLC (Open, High, Low, Close) and volume data for the desired instrument.
        #
        # Retrieves daily candle data for any scrip available back to the date of its inception.
        # The data is returned as arrays where each index corresponds to a single trading day.
        #
        # @param params [Hash{Symbol => String, Integer, Boolean}] Request parameters
        #   @option params [String] :security_id (required) Exchange standard ID for each scrip
        #   @option params [String] :exchange_segment (required) Exchange and segment for which data is to be fetched.
        #     Valid values: See {DhanHQ::Constants::EXCHANGE_SEGMENTS}
        #   @option params [String] :instrument (required) Instrument type of the scrip.
        #     Valid values: See {DhanHQ::Constants::INSTRUMENTS}
        #   @option params [Integer] :expiry_code (optional) Expiry of the instruments in case of derivatives.
        #     Valid values: 0, 1, 2
        #   @option params [Boolean] :oi (optional) Include Open Interest data for Futures & Options.
        #     Default: false
        #   @option params [String] :from_date (required) Start date of the desired range in YYYY-MM-DD format
        #   @option params [String] :to_date (required) End date of the desired range (non-inclusive) in YYYY-MM-DD format
        #
        # @return [HashWithIndifferentAccess{Symbol => Array<Float, Integer>}] Historical data hash containing:
        #   - **:open** [Array<Float>] Open prices for each trading day
        #   - **:high** [Array<Float>] High prices for each trading day
        #   - **:low** [Array<Float>] Low prices for each trading day
        #   - **:close** [Array<Float>] Close prices for each trading day
        #   - **:volume** [Array<Integer>] Volume traded for each trading day
        #   - **:timestamp** [Array<Integer>] Epoch timestamps (Unix time in seconds) for each trading day
        #   - **:open_interest** [Array<Float>] Open interest values (only included if `oi: true` was specified)
        #
        # @example Fetch daily data for equity
        #   data = DhanHQ::Models::HistoricalData.daily(
        #     security_id: "1333",
        #     exchange_segment: "NSE_EQ",
        #     instrument: "EQUITY",
        #     from_date: "2022-01-08",
        #     to_date: "2022-02-08"
        #   )
        #   data[:open].size  # => Number of trading days
        #   data[:close].first  # => First day's close price
        #
        # @example Fetch daily data with open interest for futures
        #   data = DhanHQ::Models::HistoricalData.daily(
        #     security_id: "13",
        #     exchange_segment: "NSE_FNO",
        #     instrument: "FUTIDX",
        #     expiry_code: 0,
        #     oi: true,
        #     from_date: "2024-01-01",
        #     to_date: "2024-01-31"
        #   )
        #   puts "OI data available: #{data.key?(:open_interest)}"
        #
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter
        def daily(params)
          validate_params!(params, DhanHQ::Contracts::HistoricalDataContract)
          resource.daily(params)
        end

        ##
        # Fetches intraday OHLC (Open, High, Low, Close) and volume data for minute-level timeframes.
        #
        # Retrieves minute-level candle data (1, 5, 15, 25, or 60 minutes) for desired instruments.
        # Data is available for the last 5 years for all exchanges and segments for all active instruments.
        #
        # **Important**: Only 90 days of data can be polled at once for any of the time intervals.
        # It is recommended that you store this data locally for day-to-day analysis.
        #
        # @param params [Hash{Symbol => String, Integer, Boolean}] Request parameters
        #   @option params [String] :security_id (required) Exchange standard ID for each scrip
        #   @option params [String] :exchange_segment (required) Exchange and segment for which data is to be fetched.
        #     Valid values: See {DhanHQ::Constants::EXCHANGE_SEGMENTS}
        #   @option params [String] :instrument (required) Instrument type of the scrip.
        #     Valid values: See {DhanHQ::Constants::INSTRUMENTS}
        #   @option params [String] :interval (required) Minute intervals for the timeframe.
        #     Valid values: "1", "5", "15", "25", "60"
        #   @option params [Integer] :expiry_code (optional) Expiry of the instruments in case of derivatives.
        #     Valid values: 0, 1, 2
        #   @option params [Boolean] :oi (optional) Include Open Interest data for Futures & Options.
        #     Default: false
        #   @option params [String] :from_date (required) Start date of the desired range.
        #     Format: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS (e.g., "2024-09-11" or "2024-09-11 09:30:00")
        #   @option params [String] :to_date (required) End date of the desired range.
        #     Format: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS (e.g., "2024-09-15" or "2024-09-15 13:00:00")
        #
        # @return [HashWithIndifferentAccess{Symbol => Array<Float, Integer>}] Historical data hash containing:
        #   - **:open** [Array<Float>] Open prices for each timeframe
        #   - **:high** [Array<Float>] High prices for each timeframe
        #   - **:low** [Array<Float>] Low prices for each timeframe
        #   - **:close** [Array<Float>] Close prices for each timeframe
        #   - **:volume** [Array<Integer>] Volume traded for each timeframe
        #   - **:timestamp** [Array<Integer>] Epoch timestamps (Unix time in seconds) for each timeframe
        #   - **:open_interest** [Array<Float>] Open interest values (only included if `oi: true` was specified)
        #
        # @example Fetch 15-minute intraday data
        #   data = DhanHQ::Models::HistoricalData.intraday(
        #     security_id: "1333",
        #     exchange_segment: "NSE_EQ",
        #     instrument: "EQUITY",
        #     interval: "15",
        #     from_date: "2024-09-11",
        #     to_date: "2024-09-15"
        #   )
        #   puts "Total 15-min candles: #{data[:open].size}"
        #
        # @example Fetch 1-minute data with specific time range
        #   data = DhanHQ::Models::HistoricalData.intraday(
        #     security_id: "1333",
        #     exchange_segment: "NSE_EQ",
        #     instrument: "EQUITY",
        #     interval: "1",
        #     from_date: "2024-09-11 09:30:00",
        #     to_date: "2024-09-11 15:30:00"
        #   )
        #   # Returns 1-minute candles for the specified time range
        #
        # @example Fetch intraday data for futures with open interest
        #   data = DhanHQ::Models::HistoricalData.intraday(
        #     security_id: "13",
        #     exchange_segment: "NSE_FNO",
        #     instrument: "FUTIDX",
        #     interval: "5",
        #     expiry_code: 0,
        #     oi: true,
        #     from_date: "2024-01-01",
        #     to_date: "2024-01-31"
        #   )
        #
        # @note Maximum 90 days of data can be fetched in a single request. For longer periods,
        #   make multiple requests or store data locally for analysis.
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter
        def intraday(params)
          validate_params!(params, DhanHQ::Contracts::HistoricalDataContract)
          resource.intraday(params)
        end
      end

      ##
      # HistoricalData objects are read-only, so no validation contract is applied.
      #
      # @return [nil] No validation contract needed for read-only data
      def validation_contract
        nil
      end
    end
  end
end
