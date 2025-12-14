#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test helpers for DhanHQ client gem
# Load this in console: load 'bin/test_helpers.rb'

module DhanHQ
  module TestHelpers
    # Quick configuration check
    def self.check_config
      puts "=== DhanHQ Configuration ==="
      puts "Client ID: #{DhanHQ.configuration.client_id}"
      puts "Access Token: #{DhanHQ.configuration.access_token ? 'Set' : 'Not Set'}"
      puts "WS User Type: #{DhanHQ.configuration.ws_user_type}"
      puts "Base URL: #{DhanHQ.configuration.base_url}"
      puts "============================"
    end

    # Quick test for market feed
    def self.test_market_feed
      puts "Testing Market Feed..."
      payload = { "IDX_I" => [13] } # NIFTY
      response = DhanHQ::Models::MarketFeed.ltp(payload)
      puts "NIFTY LTP: ₹#{response[:data]['IDX_I']['13'][:last_price]}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for funds
    def self.test_funds
      puts "Testing Funds..."
      funds = DhanHQ::Models::Funds.fetch
      puts "Available Margin: ₹#{funds.available_margin}"
      puts "Collateral: ₹#{funds.collateral}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for orders
    def self.test_orders
      puts "Testing Orders..."
      orders = DhanHQ::Models::Order.all
      puts "Total Orders: #{orders.size}"
      pending = orders.select { |o| o.order_status == "PENDING" }
      puts "Pending Orders: #{pending.size}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for positions
    def self.test_positions
      puts "Testing Positions..."
      positions = DhanHQ::Models::Position.all
      puts "Total Positions: #{positions.size}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for holdings
    def self.test_holdings
      puts "Testing Holdings..."
      holdings = DhanHQ::Models::Holding.all
      puts "Total Holdings: #{holdings.size}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for profile
    def self.test_profile
      puts "Testing Profile..."
      profile = DhanHQ::Models::Profile.fetch
      puts "Name: #{profile.name}"
      puts "Email: #{profile.email}"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for instrument find
    def self.test_instrument(symbol = "TCS")
      puts "Testing Instrument Find: #{symbol}..."
      instrument = DhanHQ::Models::Instrument.find("NSE_EQ", symbol)
      if instrument
        puts "Found: #{instrument.symbol_name}"
        puts "Security ID: #{instrument.security_id}"
        puts "Exchange: #{instrument.exchange_segment}"
      else
        puts "Not found"
      end
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for WebSocket connection
    def self.test_websocket(mode = :ticker, duration = 5)
      puts "Testing WebSocket (#{mode}) for #{duration} seconds..."
      client = DhanHQ::WS.connect(mode: mode) do |data|
        puts "Data: #{data}"
      end
      client.subscribe_one(segment: "IDX_I", security_id: "13") # NIFTY
      sleep(duration)
      client.stop
      puts "WebSocket test complete"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Quick test for order WebSocket
    def self.test_order_websocket(duration = 5)
      puts "Testing Order Update WebSocket for #{duration} seconds..."
      client = DhanHQ::WS::Orders.client
      client.on(:update) { |order| puts "Order Update: #{order.order_no} - #{order.status}" }
      client.start
      sleep(duration)
      client.stop
      puts "Order WebSocket test complete"
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Run all quick tests
    def self.run_all_tests
      puts "=== Running All Quick Tests ===\n\n"
      check_config
      puts "\n"
      test_funds
      puts "\n"
      test_market_feed
      puts "\n"
      test_orders
      puts "\n"
      test_positions
      puts "\n"
      test_holdings
      puts "\n"
      test_profile
      puts "\n"
      test_instrument("TCS")
      puts "\n=== All Tests Complete ==="
    end

    # Helper to create a test order (doesn't place it)
    def self.create_test_order_params
      {
        dhan_client_id: DhanHQ.configuration.client_id,
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "INTRADAY",
        order_type: "LIMIT",
        validity: "DAY",
        security_id: "11536", # TCS
        quantity: 1,
        price: 3500.0
      }
    end

    # Helper to validate order params
    def self.validate_order_params(params = nil)
      params ||= create_test_order_params
      contract = DhanHQ::Contracts::PlaceOrderContract.new
      result = contract.call(params)
      if result.success?
        puts "✅ Validation passed"
      else
        puts "❌ Validation failed:"
        result.errors.to_h.each do |key, messages|
          puts "  #{key}: #{messages.join(', ')}"
        end
      end
      result
    end

    # Helper to test margin calculation
    def self.test_margin_calculation(params = nil)
      params ||= create_test_order_params
      puts "Calculating margin for order..."
      margin = DhanHQ::Models::Margin.calculate(params)
      puts "Margin Required: ₹#{margin.margin_required}"
      puts "Available Margin: ₹#{margin.available_margin}"
      margin
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
    end

    # Helper to monitor order via WebSocket
    def self.monitor_order(order_id)
      puts "Monitoring order #{order_id} via WebSocket..."
      client = DhanHQ::WS::Orders.client
      client.on(:update) do |order|
        if order.order_no == order_id
          puts "Order Update: #{order.status} - #{order.traded_qty}/#{order.quantity}"
        end
      end
      client.start
      puts "Monitoring started. Press Ctrl+C to stop."
      client
    end
  end
end

# Make helpers available in console
def check_config
  DhanHQ::TestHelpers.check_config
end

def test_market_feed
  DhanHQ::TestHelpers.test_market_feed
end

def test_funds
  DhanHQ::TestHelpers.test_funds
end

def test_orders
  DhanHQ::TestHelpers.test_orders
end

def test_positions
  DhanHQ::TestHelpers.test_positions
end

def test_holdings
  DhanHQ::TestHelpers.test_holdings
end

def test_profile
  DhanHQ::TestHelpers.test_profile
end

def test_instrument(symbol = "TCS")
  DhanHQ::TestHelpers.test_instrument(symbol)
end

def test_websocket(mode = :ticker, duration = 5)
  DhanHQ::TestHelpers.test_websocket(mode, duration)
end

def test_order_websocket(duration = 5)
  DhanHQ::TestHelpers.test_order_websocket(duration)
end

def run_all_tests
  DhanHQ::TestHelpers.run_all_tests
end

def validate_order_params(params = nil)
  DhanHQ::TestHelpers.validate_order_params(params)
end

def test_margin_calculation(params = nil)
  DhanHQ::TestHelpers.test_margin_calculation(params)
end

def monitor_order(order_id)
  DhanHQ::TestHelpers.monitor_order(order_id)
end

puts "✅ DhanHQ Test Helpers loaded!"
puts "Available helpers:"
puts "  check_config              - Check configuration"
puts "  test_market_feed           - Test market feed API"
puts "  test_funds                 - Test funds API"
puts "  test_orders                - Test orders API"
puts "  test_positions             - Test positions API"
puts "  test_holdings              - Test holdings API"
puts "  test_profile               - Test profile API"
puts "  test_instrument(symbol)    - Test instrument find"
puts "  test_websocket(mode, sec)  - Test WebSocket"
puts "  test_order_websocket(sec)  - Test order WebSocket"
puts "  run_all_tests              - Run all quick tests"
puts "  validate_order_params(p)   - Validate order params"
puts "  test_margin_calculation(p) - Test margin calculation"
puts "  monitor_order(order_id)    - Monitor order via WS"
puts ""
puts "Example: test_funds"
