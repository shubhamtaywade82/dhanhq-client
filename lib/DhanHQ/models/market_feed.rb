# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model for fetching real-time market snapshots for multiple instruments.
    #
    # The Market Feed API provides snapshots of multiple instruments at once. You can fetch
    # LTP (Last Traded Price), OHLC (Open, High, Low, Close), or Market Depth (quote) data
    # for instruments via a single API request. Data is returned in real-time at the time
    # of the API request.
    #
    # @note **Rate Limits**: You can fetch up to 1000 instruments in a single API request
    #   with a rate limit of 1 request per second. The client's internal rate limiter
    #   automatically throttles calls to prevent exceeding limits.
    #
    # @example Fetch LTP for multiple instruments
    #   payload = {
    #     "NSE_EQ" => [11536, 3456],
    #     "NSE_FNO" => [49081, 49082]
    #   }
    #   response = DhanHQ::Models::MarketFeed.ltp(payload)
    #   nse_eq_data = response[:data]["NSE_EQ"]
    #   puts "TCS LTP: ₹#{nse_eq_data["11536"][:last_price]}"
    #
    # @example Fetch OHLC data for equity instruments
    #   payload = {
    #     "NSE_EQ" => [11536]
    #   }
    #   response = DhanHQ::Models::MarketFeed.ohlc(payload)
    #   tcs_data = response[:data]["NSE_EQ"]["11536"]
    #   puts "Open: ₹#{tcs_data[:ohlc][:open]}"
    #   puts "High: ₹#{tcs_data[:ohlc][:high]}"
    #
    # @example Fetch full market depth quote
    #   payload = {
    #     "NSE_FNO" => [49081]
    #   }
    #   response = DhanHQ::Models::MarketFeed.quote(payload)
    #   quote_data = response[:data]["NSE_FNO"]["49081"]
    #   puts "Volume: #{quote_data[:volume]}"
    #   puts "Open Interest: #{quote_data[:oi]}"
    #
    class MarketFeed < BaseModel
      class << self
        ##
        # Provides a shared instance of the MarketFeed resource.
        #
        # @return [DhanHQ::Resources::MarketFeed] The MarketFeed resource client instance
        def resource
          @resource ||= DhanHQ::Resources::MarketFeed.new
        end

        ##
        # Fetches Last Traded Price (LTP) snapshots for multiple instruments.
        #
        # Retrieves the last traded price for a list of instruments with a single API request.
        # Supports up to 1000 instruments per request, organized by exchange segment.
        #
        # @param params [Hash{String => Array<Integer>}] Request payload mapping exchange segments
        #   to arrays of security IDs. Exchange segments are keys (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ").
        #   Values are arrays of security IDs (integer identifiers for each scrip).
        #   Valid exchange segment values: "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", etc.
        #
        # @return [HashWithIndifferentAccess] Response hash containing market data.
        #   Response structure:
        #   - **:data** [Hash{String => Hash{String => Hash}}] Market data organized by exchange segment
        #     and security ID. Each instrument's data contains:
        #     - **:last_price** [Float] Last traded price of the instrument
        #   - **:status** [String] Response status (typically "success")
        #
        # @example Fetch LTP for equity and F&O instruments
        #   payload = {
        #     "NSE_EQ" => [11536],
        #     "NSE_FNO" => [49081, 49082]
        #   }
        #   response = DhanHQ::Models::MarketFeed.ltp(payload)
        #   tcs_ltp = response[:data]["NSE_EQ"]["11536"][:last_price]
        #   puts "TCS LTP: ₹#{tcs_ltp}"
        #
        # @example Access data from response
        #   response = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [11536])
        #   data = response[:data]["NSE_EQ"]["11536"]
        #   puts "Last Price: ₹#{data[:last_price]}"
        #
        def ltp(params)
          resource.ltp(params)
        end

        ##
        # Fetches OHLC (Open, High, Low, Close) data along with LTP for specified instruments.
        #
        # Retrieves the open, high, low, and close prices along with the last traded price
        # for a list of instruments. Supports up to 1000 instruments per request.
        #
        # @param params [Hash{String => Array<Integer>}] Request payload mapping exchange segments
        #   to arrays of security IDs. Exchange segments are keys (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ").
        #   Values are arrays of security IDs (integer identifiers for each scrip).
        #   Valid exchange segment values: "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", etc.
        #
        # @return [HashWithIndifferentAccess] Response hash containing OHLC market data.
        #   Response structure:
        #   - **:data** [Hash{String => Hash{String => Hash}}] Market data organized by exchange segment
        #     and security ID. Each instrument's data contains:
        #     - **:last_price** [Float] Last traded price of the instrument
        #     - **:ohlc** [Hash{Symbol => Float}] OHLC data:
        #       - **:open** [Float] Market opening price of the day
        #       - **:close** [Float] Market closing price of the day (previous day close for current session)
        #       - **:high** [Float] Day high price
        #       - **:low** [Float] Day low price
        #   - **:status** [String] Response status (typically "success")
        #
        # @note For newly listed instruments or instruments without trading activity,
        #   OHLC values may be 0. The close price typically represents the previous day's
        #   closing price during the current trading session.
        #
        # @example Fetch OHLC for equity instruments
        #   payload = {
        #     "NSE_EQ" => [11536]
        #   }
        #   response = DhanHQ::Models::MarketFeed.ohlc(payload)
        #   tcs_data = response[:data]["NSE_EQ"]["11536"]
        #   puts "Open: ₹#{tcs_data[:ohlc][:open]}"
        #   puts "High: ₹#{tcs_data[:ohlc][:high]}"
        #   puts "Low: ₹#{tcs_data[:ohlc][:low]}"
        #   puts "Close: ₹#{tcs_data[:ohlc][:close]}"
        #   puts "LTP: ₹#{tcs_data[:last_price]}"
        #
        def ohlc(params)
          resource.ohlc(params)
        end

        ##
        # Fetches full market depth data including OHLC, Open Interest, Volume, and order book depth.
        #
        # Retrieves comprehensive market data including market depth (buy/sell orders), OHLC data,
        # Open Interest (for derivatives), Volume, circuit limits, and other trading analytics
        # for specified instruments. Supports up to 1000 instruments per request.
        #
        # @param params [Hash{String => Array<Integer>}] Request payload mapping exchange segments
        #   to arrays of security IDs. Exchange segments are keys (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ").
        #   Values are arrays of security IDs (integer identifiers for each scrip).
        #   Valid exchange segment values: "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", etc.
        #
        # @return [HashWithIndifferentAccess] Response hash containing full quote market data.
        #   Response structure:
        #   - **:data** [Hash{String => Hash{String => Hash}}] Market data organized by exchange segment
        #     and security ID. Each instrument's data contains:
        #     - **:last_price** [Float] Last traded price of the instrument
        #     - **:last_quantity** [Integer] Last traded quantity
        #     - **:last_trade_time** [String] Timestamp of last trade in "DD/MM/YYYY HH:MM:SS" format
        #     - **:average_price** [Float] Volume weighted average price (VWAP) of the day
        #     - **:buy_quantity** [Integer] Total buy order quantity pending at the exchange
        #     - **:sell_quantity** [Integer] Total sell order quantity pending at the exchange
        #     - **:volume** [Integer] Total traded volume for the day
        #     - **:oi** [Integer] Open Interest in the contract (for derivatives)
        #     - **:oi_day_high** [Integer] Highest Open Interest for the day (only for NSE_FNO)
        #     - **:oi_day_low** [Integer] Lowest Open Interest for the day (only for NSE_FNO)
        #     - **:net_change** [Float] Absolute change in LTP from previous day closing price
        #     - **:upper_circuit_limit** [Float] Current upper circuit limit
        #     - **:lower_circuit_limit** [Float] Current lower circuit limit
        #     - **:ohlc** [Hash{Symbol => Float}] OHLC data:
        #       - **:open** [Float] Market opening price of the day
        #       - **:close** [Float] Market closing price of the day
        #       - **:high** [Float] Day high price
        #       - **:low** [Float] Day low price
        #     - **:depth** [Hash{Symbol => Array<Hash>}] Market depth (order book) data:
        #       - **:buy** [Array<Hash{Symbol => Integer, Float}>] Buy side depth levels (up to 5 levels):
        #         - **:quantity** [Integer] Number of quantity at this price depth
        #         - **:orders** [Integer] Number of open BUY orders at this price depth
        #         - **:price** [Float] Price at which the BUY depth stands
        #       - **:sell** [Array<Hash{Symbol => Integer, Float}>] Sell side depth levels (up to 5 levels):
        #         - **:quantity** [Integer] Number of quantity at this price depth
        #         - **:orders** [Integer] Number of open SELL orders at this price depth
        #         - **:price** [Float] Price at which the SELL depth stands
        #   - **:status** [String] Response status (typically "success")
        #
        # @note This endpoint uses a separate quote API with stricter rate limits (1 request per second).
        #   The client automatically handles rate limiting for quote requests.
        #
        # @example Fetch full quote for futures contract
        #   payload = {
        #     "NSE_FNO" => [49081]
        #   }
        #   response = DhanHQ::Models::MarketFeed.quote(payload)
        #   quote = response[:data]["NSE_FNO"]["49081"]
        #   puts "LTP: ₹#{quote[:last_price]}"
        #   puts "Volume: #{quote[:volume]}"
        #   puts "Open Interest: #{quote[:oi]}"
        #   puts "Day High OI: #{quote[:oi_day_high]}"
        #
        # @example Access market depth (order book)
        #   response = DhanHQ::Models::MarketFeed.quote("NSE_FNO" => [49081])
        #   quote = response[:data]["NSE_FNO"]["49081"]
        #   buy_depth = quote[:depth][:buy]
        #   puts "Best Buy Price: ₹#{buy_depth[0][:price]}"
        #   puts "Best Buy Quantity: #{buy_depth[0][:quantity]}"
        #
        def quote(params)
          resource.quote(params)
        end
      end
    end
  end
end
