# frozen_string_literal: true

require "csv"
require "net/http"
require "uri"

# Helper for loading and managing script data for testing
module ScriptDataHelper
  # Common security IDs for testing (these are real NSE stocks)
  COMMON_SECURITIES = {
    nse_equity: {
      "INFY" => { security_id: "4081", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "RELIANCE" => { security_id: "2881", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "TCS" => { security_id: "11536", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "HDFC" => { security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "HDFCBANK" => { security_id: "1332", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "ICICIBANK" => { security_id: "4963", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "SBIN" => { security_id: "3045", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "BHARTIARTL" => { security_id: "10604", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "ITC" => { security_id: "4244", exchange_segment: "NSE_EQ", instrument: "EQUITY" },
      "KOTAKBANK" => { security_id: "1922", exchange_segment: "NSE_EQ", instrument: "EQUITY" }
    },
    nse_fno: {
      "NIFTY" => { security_id: "13", exchange_segment: "NSE_FNO", instrument: "INDEX" },
      "BANKNIFTY" => { security_id: "23", exchange_segment: "NSE_FNO", instrument: "INDEX" },
      "FINNIFTY" => { security_id: "25", exchange_segment: "NSE_FNO", instrument: "INDEX" }
    },
    bse_fno: {
      "SENSEX" => { security_id: "1", exchange_segment: "BSE_FNO", instrument: "INDEX" }
    }
  }.freeze

  # Get a random security for testing
  def self.random_security(category = :nse_equity)
    securities = COMMON_SECURITIES[category]
    return nil unless securities

    symbol, data = securities.to_a.sample
    data.merge(symbol: symbol)
  end

  # Get a specific security by symbol
  def self.security_by_symbol(symbol, category = :nse_equity)
    securities = COMMON_SECURITIES[category]
    return nil unless securities

    data = securities[symbol.to_s.upcase]
    return nil unless data

    data.merge(symbol: symbol.to_s.upcase)
  end

  # Get multiple securities for testing
  def self.multiple_securities(count = 3, category = :nse_equity)
    securities = COMMON_SECURITIES[category]
    return [] unless securities

    securities.to_a.sample(count).map do |symbol, data|
      data.merge(symbol: symbol)
    end
  end

  # Generate test parameters for market feed APIs
  def self.market_feed_params(count = 3, category = :nse_equity)
    securities = multiple_securities(count, category)

    {
      instruments: securities.map { |s| "#{s[:exchange_segment].split("_").first}:#{s[:symbol]}" },
      fields: %w[lastPrice open high low close volume]
    }
  end

  # Generate test parameters for historical data
  def self.historical_data_params(category = :nse_equity)
    security = random_security(category)
    return {} unless security

    {
      security_id: security[:security_id],
      exchange_segment: security[:exchange_segment],
      instrument: security[:instrument],
      from_date: "2024-01-01",
      to_date: "2024-01-31"
    }
  end

  # Generate test parameters for intraday data
  def self.intraday_data_params(category = :nse_equity)
    security = random_security(category)
    return {} unless security

    {
      security_id: security[:security_id],
      exchange_segment: security[:exchange_segment],
      instrument: security[:instrument],
      interval: "15",
      from_date: "2024-01-01",
      to_date: "2024-01-02"
    }
  end

  # Generate test parameters for option chain
  def self.option_chain_params
    nifty = security_by_symbol("NIFTY", :nse_fno)
    return {} unless nifty

    {
      underlying_scrip: nifty[:security_id].to_i,
      underlying_seg: nifty[:exchange_segment],
      expiry: "2025-01-30"
    }
  end

  # Generate test parameters for orders
  def self.order_params(category = :nse_equity)
    security = random_security(category)
    return {} unless security

    {
      transaction_type: "BUY",
      exchange_segment: security[:exchange_segment],
      product_type: "CNC",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: security[:security_id],
      quantity: 1,
      price: 100.0,
      trading_symbol: security[:symbol]
    }
  end

  # Print available securities for debugging
  def self.print_available_securities
    puts "\n" + ("=" * 60)
    puts "Available Securities for Testing:"
    puts "=" * 60

    COMMON_SECURITIES.each do |category, securities|
      puts "\n#{category.to_s.upcase}:"
      securities.each do |symbol, data|
        puts "  #{symbol}: ID=#{data[:security_id]}, Segment=#{data[:exchange_segment]}"
      end
    end
    puts "=" * 60
  end
end
