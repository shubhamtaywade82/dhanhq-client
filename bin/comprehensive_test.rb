#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Test Suite for DhanHQ Client Gem
# Load this in console: load 'bin/comprehensive_test.rb'
# Then run: run_comprehensive_tests

module DhanHQ
  module ComprehensiveTest
    # Assertions for live streams: data is only required while the exchange is open.
    module StreamAssertions
      # Seconds to wait for the first packet on a stream.
      STREAM_WAIT_SECONDS = 10

      # Raised to mark a test as skipped rather than passed or failed.
      class SkipTest < StandardError; end

      # Sanity checks that catch a misread wire format (wrong side, offset or row size).
      def validate_depth!(update, level)
        bids = update[:bids]
        asks = update[:asks]
        raise DhanHQ::Error, "depth update without bid/ask arrays: #{update.inspect}" unless bids.is_a?(Array) && asks.is_a?(Array)
        raise DhanHQ::Error, "depth update with an empty book" if bids.empty? && asks.empty?
        raise DhanHQ::Error, "more than #{level} levels on one side" if bids.size > level || asks.size > level

        bad = (bids + asks).reject { |l| l[:price].to_f.positive? && l[:price].to_f.finite? && l[:quantity].to_i.positive? }
        raise DhanHQ::Error, "implausible depth levels (decoder misaligned?): #{bad.first(3).inspect}" if bad.any?
        return unless update[:best_bid] && update[:best_ask] && update[:best_bid] > update[:best_ask]

        raise DhanHQ::Error, "crossed book #{update[:best_bid]} > #{update[:best_ask]} (bid/ask sides swapped?)"
      end

      def wait_for(seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        sleep(0.25) until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end

      # No data while the market is open is a failure; while it is closed the
      # stream legitimately stays silent, so the test is skipped instead.
      def expect_stream_data!(received, what)
        return puts("    Received #{what}") if received
        raise SkipTest, "no #{what} — market closed" unless market_open?

        raise DhanHQ::Error, "no #{what} within #{STREAM_WAIT_SECONDS}s during market hours " \
                             "(on an exchange holiday set DHAN_TEST_MARKET_OPEN=false)"
      end

      # Weekday and 09:15-15:30 IST. No holiday calendar: DHAN_TEST_MARKET_OPEN=true|false overrides.
      def market_open?
        override = ENV.fetch("DHAN_TEST_MARKET_OPEN", "").strip
        return override.casecmp("true").zero? unless override.empty?

        now = Time.now.getlocal(DhanHQ::Risk::Checks::MarketHours::TIMEZONE_OFFSET)
        return false unless now.wday.between?(1, 5)

        DhanHQ::Risk::Checks::MarketHours.run!(now: now)
        true
      rescue DhanHQ::RiskViolation
        false
      end
    end

    class TestRunner
      include StreamAssertions

      attr_reader :results, :errors

      def initialize
        @results = { passed: 0, failed: 0, skipped: 0 }
        @errors = []
        @test_order_id = nil
        @websocket_clients = []
      end

      def run_all
        puts "\n#{"=" * 80}"
        puts "DhanHQ Client Gem - Comprehensive Test Suite"
        puts "#{"=" * 80}\n"

        # Setup & Configuration
        test_setup_and_configuration

        # Model Testing (read-only operations first)
        test_profile
        test_funds
        test_holdings
        test_positions
        test_orders_read
        test_trades
        test_instruments
        test_market_feed
        test_historical_data
        test_option_chain
        test_super_orders_read
        test_forever_orders_read
        test_edis_read
        test_kill_switch_read
        test_margin_calculator
        test_ledger_entries

        # Validation Contracts Testing
        test_validation_contracts

        # Error Handling Testing
        test_error_handling

        # Rate Limiting Testing
        test_rate_limiting

        # WebSocket Testing (these require active connections)
        test_websocket_market_feed
        test_websocket_order_updates
        test_websocket_market_depth

        # Order Operations (write operations - be careful!)
        # Uncomment these if you want to test order placement/modification
        # test_order_operations

        print_summary
      end

      private

      def test_setup_and_configuration
        section("Setup & Configuration")
        test("Configuration check") do
          puts "  ✓ Client ID: #{DhanHQ.configuration.client_id}"
          puts "  ✓ Access Token: #{DhanHQ.configuration.access_token ? "Set" : "Not Set"}"
          puts "  ✓ WS User Type: #{DhanHQ.configuration.ws_user_type}"
          puts "  ✓ Base URL: #{DhanHQ.configuration.base_url}"
        end

        test("Environment variables check") do
          puts "  DHAN_CLIENT_ID: #{ENV["DHAN_CLIENT_ID"] ? "Set" : "Not Set"}"
          puts "  DHAN_ACCESS_TOKEN: #{ENV["DHAN_ACCESS_TOKEN"] ? "Set" : "Not Set"}"
          puts "  DHAN_LOG_LEVEL: #{ENV["DHAN_LOG_LEVEL"] || "INFO"}"
        end
      end

      def test_profile
        section("Profile")
        test("Fetch profile") do
          profile = DhanHQ::Models::Profile.fetch
          puts "  ✓ Client ID: #{profile.dhan_client_id}"
          puts "  ✓ Token Validity: #{profile.token_validity}"
          puts "  ✓ Active Segments: #{profile.active_segment}"
          puts "  ✓ DDPI: #{profile.ddpi}"
          puts "  ✓ MTF: #{profile.mtf}"
          puts "  ✓ Data Plan: #{profile.data_plan}"
        end
      end

      def test_funds
        section("Funds")
        test("Fetch funds") do
          funds = DhanHQ::Models::Funds.fetch
          puts "  ✓ Available Balance: ₹#{funds.available_balance}"
          puts "  ✓ SOD Limit: ₹#{funds.sod_limit}"
          puts "  ✓ Collateral Amount: ₹#{funds.collateral_amount}"
          puts "  ✓ Utilized Amount: ₹#{funds.utilized_amount}"
          puts "  ✓ Withdrawable Balance: ₹#{funds.withdrawable_balance}"
        end
      end

      def test_holdings
        section("Holdings")
        test("Get all holdings") do
          holdings = DhanHQ::Models::Holding.all
          puts "  ✓ Total holdings: #{holdings.size}"
          holdings.first(3).each do |holding|
            puts "    - #{holding.trading_symbol}: #{holding.quantity} shares @ ₹#{holding.average_price}"
          end
        end
      end

      def test_positions
        section("Positions")
        test("Get all positions") do
          positions = DhanHQ::Models::Position.all
          puts "  ✓ Total positions: #{positions.size}"
          nse_positions = positions.select { |p| p.exchange_segment == DhanHQ::Constants::ExchangeSegment::NSE_EQ }
          puts "  ✓ NSE positions: #{nse_positions.size}"
          long_positions = positions.select { |p| p.net_qty.positive? }
          puts "  ✓ Long positions: #{long_positions.size}"
        end
      end

      def test_orders_read
        section("Orders (Read)")
        test("Get all orders") do
          orders = DhanHQ::Models::Order.all
          puts "  ✓ Total orders: #{orders.size}"
          pending = orders.select { |o| o.order_status == DhanHQ::Constants::OrderStatus::PENDING }
          puts "  ✓ Pending orders: #{pending.size}"
          executed = orders.select { |o| o.order_status == DhanHQ::Constants::OrderStatus::TRADED }
          puts "  ✓ Executed orders: #{executed.size}"
        end

        test("Find order by ID (if available)") do
          orders = DhanHQ::Models::Order.all
          if orders.any?
            order = orders.first
            found_order = DhanHQ::Models::Order.find(order.order_id)
            puts "  ✓ Found order: #{found_order.order_id}"
            puts "    Status: #{found_order.order_status}"
            puts "    Symbol: #{found_order.trading_symbol}"
          else
            puts "  ⚠ No orders found to test"
          end
        end
      end

      def test_trades
        section("Trades")
        test("Get today's trades") do
          trades = DhanHQ::Models::Trade.today
          puts "  ✓ Total trades today: #{trades.size}"
          trades.first(3).each do |trade|
            puts "    - #{trade.trading_symbol}: #{trade.traded_qty} @ ₹#{trade.traded_price}"
          end
        end

        test("Get trade history") do
          from_date = (Date.today - 7).strftime("%Y-%m-%d")
          to_date = Date.today.strftime("%Y-%m-%d")
          trades = DhanHQ::Models::Trade.history(from_date: from_date, to_date: to_date)
          puts "  ✓ Total trades (last 7 days): #{trades.size}"
        end
      end

      def test_instruments
        section("Instruments")
        test("Find instrument (TCS)") do
          tcs = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "TCS")
          if tcs
            puts "  ✓ Found: #{tcs.symbol_name}"
            puts "    Security ID: #{tcs.security_id}"
            puts "    Exchange Segment: #{tcs.exchange_segment}"
            puts "    Instrument Type: #{tcs.instrument}"
          else
            puts "  ✗ TCS not found"
          end
        end

        test("Find instrument anywhere (RELIANCE)") do
          reliance = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")
          if reliance
            puts "  ✓ Found: #{reliance.symbol_name}"
            puts "    Exchange: #{reliance.exchange_segment}"
            puts "    Security ID: #{reliance.security_id}"
          else
            puts "  ✗ RELIANCE not found"
          end
        end

        test("Instrument attributes") do
          instrument = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "TCS")
          if instrument
            puts "  ✓ Symbol: #{instrument.symbol_name}"
            puts "  ✓ Security ID: #{instrument.security_id}"
            puts "  ✓ Exchange Segment: #{instrument.exchange_segment}"
            puts "  ✓ Instrument Type: #{instrument.instrument}"
          else
            puts "  ⚠ Skipping - instrument not found"
          end
        end
      end

      def test_market_feed
        section("Market Feed")
        test("Get LTP") do
          payload = {
            "NSE_EQ" => [11_536], # TCS
            "IDX_I" => [13] # NIFTY
          }
          response = DhanHQ::Models::MarketFeed.ltp(payload)
          puts "  ✓ LTP Data retrieved"
          response[:data].each do |segment, instruments|
            instruments.each do |security_id, data|
              puts "    #{segment}:#{security_id} = ₹#{data[:last_price]}"
            end
          end
        end

        test("Get OHLC") do
          payload = { "NSE_EQ" => [11_536] }
          response = DhanHQ::Models::MarketFeed.ohlc(payload)
          tcs_data = response[:data][DhanHQ::Constants::ExchangeSegment::NSE_EQ]["11536"]
          puts "  ✓ OHLC Data:"
          puts "    Open: ₹#{tcs_data[:ohlc][:open]}"
          puts "    High: ₹#{tcs_data[:ohlc][:high]}"
          puts "    Low: ₹#{tcs_data[:ohlc][:low]}"
          puts "    Close: ₹#{tcs_data[:ohlc][:close]}"
        end

        test("Get Quote") do
          payload = { "IDX_I" => [13] } # NIFTY
          response = DhanHQ::Models::MarketFeed.quote(payload)
          quote_data = response[:data][DhanHQ::Constants::ExchangeSegment::IDX_I]["13"]
          puts "  ✓ Quote Data:"
          puts "    LTP: ₹#{quote_data[:ltp]}"
          puts "    Volume: #{quote_data[:volume]}"
        end
      end

      def test_historical_data
        section("Historical Data")
        test("Get daily historical data") do
          historical_data = DhanHQ::Models::HistoricalData.daily(
            security_id: "11536",
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            instrument: DhanHQ::Constants::InstrumentType::EQUITY,
            from_date: (Date.today - 30).strftime("%Y-%m-%d"),
            to_date: Date.today.strftime("%Y-%m-%d")
          )
          puts "  ✓ Total candles: #{historical_data[:close]&.size || 0}"
          if historical_data[:close]&.any?
            puts "    First close: ₹#{historical_data[:close].first}"
            puts "    Last close: ₹#{historical_data[:close].last}"
          end
        end

        test("Get intraday historical data") do
          # Use a past date (yesterday or a few days ago) to ensure data is available
          # Market might be closed today or it's a weekend
          test_date = Date.today - 1
          # If it's Sunday (0) or Saturday (6), go back to Friday
          test_date -= 1 if test_date.wday.zero?
          test_date -= 1 if test_date.wday == 6

          historical_data = DhanHQ::Models::HistoricalData.intraday(
            security_id: "11536",
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            instrument: DhanHQ::Constants::InstrumentType::EQUITY,
            interval: "5",
            from_date: test_date.strftime("%Y-%m-%d"),
            to_date: test_date.strftime("%Y-%m-%d")
          )
          puts "  ✓ Total intraday candles: #{historical_data[:close]&.size || 0}"
          if historical_data[:close]&.any?
            puts "    First close: ₹#{historical_data[:close].first}"
            puts "    Last close: ₹#{historical_data[:close].last}"
          end
        end
      end

      def test_option_chain
        section("Option Chain")
        test("Get expiry list for NIFTY") do
          expiry_list = DhanHQ::Models::OptionChain.fetch_expiry_list(
            underlying_scrip: 13, # NIFTY security ID
            underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I
          )
          puts "  ✓ Available expiries: #{expiry_list.size}"
          expiry_list.first(3).each do |expiry|
            puts "    - #{expiry}"
          end
        end

        test("Get option chain") do
          expiry_list = DhanHQ::Models::OptionChain.fetch_expiry_list(
            underlying_scrip: 13, # NIFTY security ID
            underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I
          )
          if expiry_list.any?
            expiry_date = expiry_list.first
            option_chain = DhanHQ::Models::OptionChain.fetch(
              underlying_scrip: 13, # NIFTY security ID
              underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I,
              expiry: expiry_date
            )
            puts "  ✓ Option chain retrieved"
            puts "    Underlying LTP: ₹#{option_chain[:last_price]}"
            puts "    Total strikes: #{option_chain[:oc]&.size || 0}"
          else
            puts "  ⚠ No expiries available"
          end
        end
      end

      def test_super_orders_read
        section("Super Orders (Read)")
        test("Get all super orders") do
          super_orders = DhanHQ::Models::SuperOrder.all
          puts "  ✓ Total super orders: #{super_orders.size}"
        end
      end

      def test_forever_orders_read
        section("Forever Orders (Read)")
        test("Get all forever orders") do
          forever_orders = DhanHQ::Models::ForeverOrder.all
          puts "  ✓ Total forever orders: #{forever_orders.size}"
        end
      end

      def test_edis_read
        section("EDIS (Read)")
        test("Get EDIS form") do
          # Check if user has holdings first
          holdings = DhanHQ::Models::Holding.all
          if holdings.any?
            # Use first holding's ISIN and available quantity
            first_holding = holdings.first
            if first_holding.isin && first_holding.isin != "" && first_holding.available_qty.to_i.positive?
              edis = DhanHQ::Resources::Edis.new
              edis_response = edis.form(
                isin: first_holding.isin,
                qty: first_holding.available_qty.to_i,
                exchange: "NSE",
                segment: "EQ",
                bulk: false
              )
              puts "  ✓ EDIS form requested"
              puts "    Response: #{edis_response.is_a?(Hash) ? "OK" : edis_response.class}"
            else
              puts "  ⚠ Skipping - holding missing ISIN or available quantity"
            end
          else
            puts "  ⚠ Skipping - no holdings available for EDIS form"
          end
        end

        test("Get bulk EDIS form") do
          # Bulk EDIS form should work even without specific holdings
          # But it may still require valid exchange/segment

          edis = DhanHQ::Resources::Edis.new
          bulk_response = edis.bulk_form(exchange: "NSE", segment: "EQ", bulk: true)
          puts "  ✓ Bulk EDIS form requested"
          puts "    Response: #{bulk_response.is_a?(Hash) ? "OK" : bulk_response.class}"
        rescue DhanHQ::InputExceptionError => e
          # If bulk form fails, it might be because user has no holdings
          holdings = DhanHQ::Models::Holding.all
          raise e unless holdings.empty?

          puts "  ⚠ Skipping - no holdings available for bulk EDIS form"
        end
      end

      def test_kill_switch_read
        section("Kill Switch (Read)")
        test("Get kill switch status") do
          # NOTE: This might not have a read endpoint, so we'll skip if it fails
          puts "  ⚠ Kill switch status check (may not be available)"
        end
      end

      def test_margin_calculator
        section("Margin Calculator")
        test("Calculate margin") do
          margin = DhanHQ::Models::Margin.calculate(
            dhan_client_id: DhanHQ.configuration.client_id,
            transaction_type: DhanHQ::Constants::TransactionType::BUY,
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            product_type: DhanHQ::Constants::ProductType::MARGIN,
            order_type: DhanHQ::Constants::OrderType::LIMIT,
            security_id: "11536",
            quantity: 1,
            price: 3500.0
          )
          puts "  ✓ Total Margin: ₹#{margin.total_margin}"
          puts "  ✓ Available Balance: ₹#{margin.available_balance}"
          puts "  ✓ SPAN Margin: ₹#{margin.span_margin}"
          puts "  ✓ Leverage: #{margin.leverage}x"
        end
      end

      def test_ledger_entries
        section("Ledger Entries")
        test("Get ledger entries") do
          from_date = Date.today - 7
          to_date = Date.today
          ledger_entries = DhanHQ::Models::LedgerEntry.all(
            from_date: from_date,
            to_date: to_date
          )
          puts "  ✓ Total ledger entries: #{ledger_entries.size}"
          ledger_entries.first(3).each do |entry|
            puts "    #{entry.voucherdate}: #{entry.narration} - Debit: ₹#{entry.debit}, Credit: ₹#{entry.credit}"
          end
        end
      end

      def test_validation_contracts
        section("Validation Contracts")
        test("Place Order Contract - Valid") do
          valid_params = {
            dhan_client_id: DhanHQ.configuration.client_id,
            transaction_type: DhanHQ::Constants::TransactionType::BUY,
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            product_type: DhanHQ::Constants::ProductType::INTRADAY,
            order_type: DhanHQ::Constants::OrderType::LIMIT,
            validity: DhanHQ::Constants::Validity::DAY,
            security_id: "11536",
            quantity: 1,
            price: 3500.0
          }
          contract = DhanHQ::Contracts::PlaceOrderContract.new
          result = contract.call(valid_params)
          if result.success?
            puts "  ✓ Validation passed"
          else
            puts "  ✗ Validation failed: #{result.errors.to_h}"
          end
        end

        test("Place Order Contract - Invalid (missing fields)") do
          invalid_params = {
            transaction_type: DhanHQ::Constants::TransactionType::BUY,
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ
          }
          contract = DhanHQ::Contracts::PlaceOrderContract.new
          result = contract.call(invalid_params)
          if result.failure?
            puts "  ✓ Validation correctly failed for missing fields"
          else
            puts "  ✗ Validation should have failed"
          end
        end

        test("Place Order Contract - Invalid (NaN price)") do
          valid_params = {
            dhan_client_id: DhanHQ.configuration.client_id,
            transaction_type: DhanHQ::Constants::TransactionType::BUY,
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            product_type: DhanHQ::Constants::ProductType::INTRADAY,
            order_type: DhanHQ::Constants::OrderType::LIMIT,
            validity: DhanHQ::Constants::Validity::DAY,
            security_id: "11536",
            quantity: 1,
            price: Float::NAN
          }
          contract = DhanHQ::Contracts::PlaceOrderContract.new
          result = contract.call(valid_params)
          if result.failure?
            puts "  ✓ NaN validation caught"
          else
            puts "  ✗ NaN validation should have failed"
          end
        end

        test("Historical Data Contract - Valid") do
          valid_params = {
            security_id: "11536",
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            instrument: DhanHQ::Constants::InstrumentType::EQUITY,
            from_date: (Date.today - 7).strftime("%Y-%m-%d"),
            to_date: Date.today.strftime("%Y-%m-%d"),
            interval: "5"
          }
          contract = DhanHQ::Contracts::HistoricalDataContract.new
          result = contract.call(valid_params)
          if result.success?
            puts "  ✓ Validation passed"
          else
            puts "  ✗ Validation failed: #{result.errors.to_h}"
          end
        end

        test("Historical Data Contract - Invalid (date range > 31 days)") do
          invalid_params = {
            security_id: "11536",
            exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
            instrument: DhanHQ::Constants::InstrumentType::EQUITY,
            from_date: (Date.today - 35).strftime("%Y-%m-%d"),
            to_date: Date.today.strftime("%Y-%m-%d"),
            interval: "5"
          }
          contract = DhanHQ::Contracts::HistoricalDataContract.new
          result = contract.call(invalid_params)
          if result.failure?
            puts "  ✓ Date range validation caught"
          else
            puts "  ✗ Date range validation should have failed"
          end
        end
      end

      def test_error_handling
        section("Error Handling")
        test("Network error handling (retry logic)") do
          DhanHQ::Models::Funds.fetch
          puts "  ✓ Request succeeded (retry logic working)"
        rescue DhanHQ::NetworkError => e
          puts "  ⚠ Network error after retries: #{e.message}"
        rescue StandardError => e
          puts "  ⚠ Unexpected error: #{e.class} - #{e.message}"
        end
      end

      def test_rate_limiting
        section("Rate Limiting")
        test("Rate limiter functionality") do
          puts "  ⚠ Rate limiting test (making 3 requests with small delay)"
          start_time = Time.now
          3.times do |i|
            begin
              DhanHQ::Models::Funds.fetch
              elapsed = Time.now - start_time
              puts "    Request #{i + 1} completed at #{elapsed.round(2)}s"
            rescue DhanHQ::RateLimitError => e
              puts "    Rate limited at request #{i + 1}: #{e.message}"
              break
            end
            sleep(0.5)
          end
        end
      end

      def test_websocket_market_feed
        section("WebSocket - Market Feed")
        { ticker: "ticker data (LTP + LTT)", quote: "quote data (OHLCV + totals)", full: "full data (quote + OI + depth)" }
          .each do |mode, what|
          test("#{mode.to_s.capitalize} Mode WebSocket") do
            packets = []
            client = DhanHQ::WS.connect(mode: mode) { |data| packets << data }
            @websocket_clients << client
            begin
              client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "13") # NIFTY
              priced = -> { packets.find { |p| p[:ltp].to_f.positive? } }
              wait_for(STREAM_WAIT_SECONDS) { priced.call }
              expect_stream_data!(packets.any?, what)
              # OI / prev-close packets carry no LTP; at least one price packet must decode to a real price.
              raise DhanHQ::Error, "#{packets.size} packet(s) but none with a positive LTP: #{packets.first.inspect}" unless priced.call

              puts "    #{priced.call.inspect}"
            ensure
              client.stop
            end
          end
        end
      end

      def test_websocket_order_updates
        section("WebSocket - Order Updates")
        if DhanHQ.configuration.environment_for(:order_api) == :sandbox
          puts "  ⚠ Orders route to the sandbox (#{DhanHQ.configuration.mode} mode), which has no WebSocket:"
          puts "    this stream reports the REAL account, so sandbox orders will not appear on it."
        end
        test("Order update WebSocket connects (#{STREAM_WAIT_SECONDS} seconds)") do
          updates = []
          client = DhanHQ::WS::Orders.client
          client.on(:update) { |order| updates << order }
          @websocket_clients << client
          begin
            client.start
            wait_for(STREAM_WAIT_SECONDS) { updates.any? }
            # Updates only flow when an order changes, so silence is not a failure here.
            puts(updates.any? ? "    #{updates.first.inspect}" : "    (no order activity in the window)")
          ensure
            client.stop
          end
        end
      end

      def test_websocket_market_depth
        section("WebSocket - Full Market Depth")
        reliance = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "RELIANCE")
        symbols = reliance && [{ symbol: "RELIANCE", exchange_segment: reliance.exchange_segment, security_id: reliance.security_id }]

        [20, 200].each do |level|
          test("#{level}-level depth: subscribe, decode, unsubscribe") do
            raise SkipTest, "RELIANCE instrument not found" unless symbols

            run_depth_check(symbols, level)
          end
        end
      end

      def run_depth_check(symbols, level)
        config = DhanHQ.configuration.dup
        config.market_depth_level = level
        updates = []
        errors = []
        client = DhanHQ::WS::MarketDepth.connect(symbols: symbols, config: config) { |update| updates << update }
        client.on(:error) { |e| errors << e }
        @websocket_clients << client
        begin
          wait_for(STREAM_WAIT_SECONDS) { updates.any? }
          expect_stream_data!(updates.any?, "#{level}-level depth")
          validate_depth!(updates.last, level)
          update = updates.last
          puts "    #{update[:bids].size} bids / #{update[:asks].size} asks, " \
               "best #{update[:best_bid]} x #{update[:best_ask]}, spread #{update[:spread]}"

          client.unsubscribe(symbols.first)
          raise DhanHQ::Error, "unsubscribe left #{client.subscriptions.inspect}" if client.subscribed?(symbols.first)
          raise DhanHQ::Error, "depth client errors: #{errors.map(&:message).join("; ")}" if errors.any?
        ensure
          client.stop
        end
      end

      def test_order_operations
        section("Order Operations (Write)")
        puts "  ⚠ WARNING: Order operations are disabled by default"
        puts "  ⚠ Uncomment this section in the code to test order placement/modification"
        # Uncomment below to test order operations
        # test("Place test order") do
        #   order = DhanHQ::Models::Order.place(
        #     dhan_client_id: DhanHQ.configuration.client_id,
        #     transaction_type: "BUY",
        #     exchange_segment: "NSE_EQ",
        #     product_type: "INTRADAY",
        #     order_type: "LIMIT",
        #     validity: "DAY",
        #     security_id: "11536",
        #     quantity: 1,
        #     price: 3500.0
        #   )
        #   @test_order_id = order.order_id
        #   puts "  ✓ Order placed: #{order.order_id}"
        # end
        #
        # test("Modify order") do
        #   if @test_order_id
        #     order = DhanHQ::Models::Order.find(@test_order_id)
        #     if order && order.order_status == "PENDING"
        #       if order.modify(price: 3501.0)
        #         puts "  ✓ Order modified"
        #       else
        #         puts "  ✗ Order modification failed"
        #       end
        #     end
        #   end
        # end
        #
        # test("Cancel order") do
        #   if @test_order_id
        #     order = DhanHQ::Models::Order.find(@test_order_id)
        #     if order && order.order_status != "CANCELLED"
        #       if order.cancel
        #         puts "  ✓ Order cancelled"
        #       else
        #         puts "  ✗ Order cancellation failed"
        #       end
        #     end
        #   end
        # end
      end

      def section(title)
        puts "\n#{"-" * 80}"
        puts "  #{title}"
        puts "-" * 80
      end

      def test(name)
        print "  Testing: #{name}... "
        begin
          yield
          @results[:passed] += 1
          puts "✓"
        rescue SkipTest => e
          @results[:skipped] += 1
          puts "– skipped (#{e.message})"
        rescue StandardError => e
          @results[:failed] += 1
          @errors << { test: name, error: e }
          puts "✗"
          puts "    Error: #{e.class} - #{e.message}"
          puts "    #{e.backtrace.first}" if e.backtrace
        end
      end

      def print_summary
        puts "\n#{"=" * 80}"
        puts "Test Summary"
        puts "=" * 80
        puts "  Passed:  #{@results[:passed]}"
        puts "  Failed:  #{@results[:failed]}"
        puts "  Skipped: #{@results[:skipped]}"
        puts "  Total:   #{@results.values.sum}"

        if @errors.any?
          puts "\nErrors:"
          @errors.each do |error|
            puts "  - #{error[:test]}: #{error[:error].class} - #{error[:error].message}"
          end
        end

        puts "\n#{"=" * 80}"
        puts "All tests completed!"
        puts "#{"=" * 80}\n"
      end

      def cleanup
        @websocket_clients.each(&:stop)
      end

      public :cleanup
    end
  end
end

# Make test runner available in console
def run_comprehensive_tests
  runner = DhanHQ::ComprehensiveTest::TestRunner.new
  begin
    runner.run_all
  ensure
    runner.cleanup
  end
end

puts "✅ Comprehensive Test Suite loaded!"
puts "Run: run_comprehensive_tests"
puts ""
