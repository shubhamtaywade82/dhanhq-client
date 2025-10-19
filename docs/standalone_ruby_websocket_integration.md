# Standalone Ruby WebSocket Integration Guide

This guide provides comprehensive instructions for integrating DhanHQ WebSocket connections into standalone Ruby applications, including scripts, daemons, and command-line tools.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Script Patterns](#script-patterns)
4. [Daemon Integration](#daemon-integration)
5. [Command-Line Tools](#command-line-tools)
6. [Error Handling](#error-handling)
7. [Production Considerations](#production-considerations)
8. [Best Practices](#best-practices)

## Quick Start

### 1. Install the Gem

```bash
gem install dhan_hq
```

### 2. Basic Configuration

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

# Market Feed WebSocket
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to major indices
market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT
market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX

# Wait for data
sleep(30)

# Clean shutdown
market_client.stop
```

### 3. Run the Script

```bash
# Set environment variables
export CLIENT_ID="your_client_id"
export ACCESS_TOKEN="your_access_token"

# Run the script
ruby market_feed_script.rb
```

## Configuration

### Environment Variables

```bash
# Required
export CLIENT_ID="your_client_id"
export ACCESS_TOKEN="your_access_token"

# Optional
export DHAN_WS_USER_TYPE="SELF"  # or "PARTNER"
export DHAN_PARTNER_ID="your_partner_id"  # if using PARTNER
export DHAN_PARTNER_SECRET="your_partner_secret"  # if using PARTNER
```

### Configuration File

```ruby
# config/dhanhq.yml
development:
  client_id: "your_dev_client_id"
  access_token: "your_dev_access_token"
  ws_user_type: "SELF"

production:
  client_id: "your_prod_client_id"
  access_token: "your_prod_access_token"
  ws_user_type: "SELF"
```

```ruby
# config/configuration.rb
require 'yaml'

class Configuration
  def self.load
    config = YAML.load_file('config/dhanhq.yml')
    env = ENV['RACK_ENV'] || 'development'
    config[env]
  end
end

# Usage
config = Configuration.load
DhanHQ.configure do |c|
  c.client_id = config['client_id']
  c.access_token = config['access_token']
  c.ws_user_type = config['ws_user_type']
end
```

## Script Patterns

### Market Feed Script

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class MarketFeedScript
  def initialize
    @market_client = nil
    @running = false
  end

  def start
    puts "Starting Market Feed WebSocket..."
    @running = true

    @market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_market_data(tick)
    end

    # Add error handling
    @market_client.on(:error) do |error|
      puts "❌ WebSocket Error: #{error}"
      @running = false
    end

    @market_client.on(:close) do |close_info|
      puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
      @running = false
    end

    # Subscribe to indices
    subscribe_to_indices

    # Wait for data
    wait_for_data
  end

  def stop
    puts "Stopping Market Feed WebSocket..."
    @running = false
    @market_client&.stop
  end

  private

  def subscribe_to_indices
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      @market_client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      puts "✅ Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})"
    end
  end

  def process_market_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    data = {
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: timestamp.iso8601,
      name: get_index_name(tick[:segment], tick[:security_id])
    }

    # Display data
    puts "📊 Market Data: #{data[:name]} = #{data[:ltp]} at #{data[:timestamp]}"

    # Save to file (optional)
    save_to_file(data)

    # Send to external service (optional)
    send_to_external_service(data)
  end

  def get_index_name(segment, security_id)
    case "#{segment}:#{security_id}"
    when "IDX_I:13" then "NIFTY"
    when "IDX_I:25" then "BANKNIFTY"
    when "IDX_I:29" then "NIFTYIT"
    when "IDX_I:51" then "SENSEX"
    else "#{segment}:#{security_id}"
    end
  end

  def save_to_file(data)
    File.open("market_data.json", "a") do |file|
      file.puts(data.to_json)
    end
  end

  def send_to_external_service(data)
    # Example: Send to external API
    # HTTP.post("https://api.example.com/market-data", data.to_json)
  end

  def wait_for_data
    puts "Waiting for market data... Press Ctrl+C to stop"
    begin
      while @running
        sleep(1)
      end
    rescue Interrupt
      puts "\nReceived interrupt signal, shutting down..."
      stop
    end
  end
end

# Run the script
script = MarketFeedScript.new
script.start
```

### Order Update Script

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class OrderUpdateScript
  def initialize
    @orders_client = nil
    @running = false
  end

  def start
    puts "Starting Order Update WebSocket..."
    @running = true

    @orders_client = DhanHQ::WS::Orders.connect do |order_update|
      process_order_update(order_update)
    end

    # Add comprehensive event handling
    @orders_client.on(:update) do |order_update|
      puts "📝 Order Updated: #{order_update.order_no}"
    end

    @orders_client.on(:status_change) do |change_data|
      puts "🔄 Status Changed: #{change_data[:previous_status]} -> #{change_data[:new_status]}"
    end

    @orders_client.on(:execution) do |execution_data|
      puts "✅ Execution: #{execution_data[:new_traded_qty]} shares executed"
    end

    @orders_client.on(:order_traded) do |order_update|
      puts "💰 Order Traded: #{order_update.order_no} - #{order_update.symbol}"
    end

    @orders_client.on(:order_rejected) do |order_update|
      puts "❌ Order Rejected: #{order_update.order_no} - #{order_update.reason_description}"
    end

    @orders_client.on(:error) do |error|
      puts "⚠️  WebSocket Error: #{error}"
      @running = false
    end

    @orders_client.on(:close) do |close_info|
      puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
      @running = false
    end

    # Wait for updates
    wait_for_updates
  end

  def stop
    puts "Stopping Order Update WebSocket..."
    @running = false
    @orders_client&.stop
  end

  private

  def process_order_update(order_update)
    data = {
      order_no: order_update.order_no,
      status: order_update.status,
      symbol: order_update.symbol,
      quantity: order_update.quantity,
      traded_qty: order_update.traded_qty,
      price: order_update.price,
      execution_percentage: order_update.execution_percentage,
      timestamp: Time.current.iso8601
    }

    # Display data
    puts "📊 Order Update: #{data[:order_no]} - #{data[:status]}"
    puts "   Symbol: #{data[:symbol]}"
    puts "   Quantity: #{data[:quantity]}"
    puts "   Traded Qty: #{data[:traded_qty]}"
    puts "   Price: #{data[:price]}"
    puts "   Execution: #{data[:execution_percentage]}%"
    puts "   ---"

    # Save to file (optional)
    save_to_file(data)

    # Send to external service (optional)
    send_to_external_service(data)
  end

  def save_to_file(data)
    File.open("order_updates.json", "a") do |file|
      file.puts(data.to_json)
    end
  end

  def send_to_external_service(data)
    # Example: Send to external API
    # HTTP.post("https://api.example.com/order-updates", data.to_json)
  end

  def wait_for_updates
    puts "Waiting for order updates... Press Ctrl+C to stop"
    begin
      while @running
        sleep(1)
      end
    rescue Interrupt
      puts "\nReceived interrupt signal, shutting down..."
      stop
    end
  end
end

# Run the script
script = OrderUpdateScript.new
script.start
```

### Market Depth Script

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class MarketDepthScript
  def initialize
    @depth_client = nil
    @running = false
  end

  def start
    puts "Starting Market Depth WebSocket..."
    @running = true

    # Define symbols with correct exchange segments and security IDs
    symbols = [
      { symbol: "RELIANCE", exchange_segment: "NSE_EQ", security_id: "2885" },
      { symbol: "TCS", exchange_segment: "NSE_EQ", security_id: "11536" }
    ]

    @depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
      process_market_depth(depth_data)
    end

    # Add event handlers
    @depth_client.on(:depth_update) do |update_data|
      puts "📊 Depth Update: #{update_data[:symbol]} - #{update_data[:side]} side updated"
    end

    @depth_client.on(:depth_snapshot) do |snapshot_data|
      puts "📸 Depth Snapshot: #{snapshot_data[:symbol]} - Full order book received"
    end

    @depth_client.on(:error) do |error|
      puts "⚠️  WebSocket Error: #{error}"
      @running = false
    end

    @depth_client.on(:close) do |close_info|
      puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
      @running = false
    end

    # Wait for data
    wait_for_data
  end

  def stop
    puts "Stopping Market Depth WebSocket..."
    @running = false
    @depth_client&.stop
  end

  private

  def process_market_depth(depth_data)
    data = {
      symbol: depth_data[:symbol],
      exchange_segment: depth_data[:exchange_segment],
      security_id: depth_data[:security_id],
      best_bid: depth_data[:best_bid],
      best_ask: depth_data[:best_ask],
      spread: depth_data[:spread],
      bid_levels: depth_data[:bids],
      ask_levels: depth_data[:asks],
      timestamp: Time.current.iso8601
    }

    # Display data
    puts "📊 Market Depth: #{data[:symbol]}"
    puts "   Best Bid: #{data[:best_bid]}"
    puts "   Best Ask: #{data[:best_ask]}"
    puts "   Spread: #{data[:spread]}"
    puts "   Bid Levels: #{data[:bid_levels].size}"
    puts "   Ask Levels: #{data[:ask_levels].size}"

    # Show top 3 bid/ask levels
    if data[:bid_levels] && data[:bid_levels].size > 0
      puts "   Top Bids:"
      data[:bid_levels].first(3).each_with_index do |bid, i|
        puts "     #{i+1}. Price: #{bid[:price]}, Qty: #{bid[:quantity]}"
      end
    end

    if data[:ask_levels] && data[:ask_levels].size > 0
      puts "   Top Asks:"
      data[:ask_levels].first(3).each_with_index do |ask, i|
        puts "     #{i+1}. Price: #{ask[:price]}, Qty: #{ask[:quantity]}"
      end
    end

    puts "   ---"

    # Save to file (optional)
    save_to_file(data)

    # Send to external service (optional)
    send_to_external_service(data)
  end

  def save_to_file(data)
    File.open("market_depth.json", "a") do |file|
      file.puts(data.to_json)
    end
  end

  def send_to_external_service(data)
    # Example: Send to external API
    # HTTP.post("https://api.example.com/market-depth", data.to_json)
  end

  def wait_for_data
    puts "Waiting for market depth data... Press Ctrl+C to stop"
    begin
      while @running
        sleep(1)
      end
    rescue Interrupt
      puts "\nReceived interrupt signal, shutting down..."
      stop
    end
  end
end

# Run the script
script = MarketDepthScript.new
script.start
```

## Daemon Integration

### Systemd Service

```ini
# /etc/systemd/system/dhanhq-market-feed.service
[Unit]
Description=DhanHQ Market Feed Daemon
After=network.target

[Service]
Type=simple
User=dhanhq
Group=dhanhq
WorkingDirectory=/opt/dhanhq-market-feed
ExecStart=/usr/bin/ruby market_feed_daemon.rb
Restart=always
RestartSec=10
Environment=CLIENT_ID=your_client_id
Environment=ACCESS_TOKEN=your_access_token
Environment=DHAN_WS_USER_TYPE=SELF

[Install]
WantedBy=multi-user.target
```

### Daemon Script

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'
require 'fileutils'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class MarketFeedDaemon
  def initialize
    @market_client = nil
    @running = false
    @pid_file = "/tmp/dhanhq-market-feed.pid"
    @log_file = "/var/log/dhanhq-market-feed.log"
  end

  def start
    if running?
      puts "Daemon is already running (PID: #{pid})"
      return
    end

    puts "Starting DhanHQ Market Feed Daemon..."
    @running = true

    # Create PID file
    File.write(@pid_file, Process.pid)

    # Set up signal handlers
    setup_signal_handlers

    # Start WebSocket connection
    start_websocket

    # Main loop
    main_loop
  end

  def stop
    puts "Stopping DhanHQ Market Feed Daemon..."
    @running = false
    @market_client&.stop
    File.delete(@pid_file) if File.exist?(@pid_file)
  end

  def status
    if running?
      puts "Daemon is running (PID: #{pid})"
    else
      puts "Daemon is not running"
    end
  end

  private

  def running?
    return false unless File.exist?(@pid_file)

    pid = File.read(@pid_file).to_i
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::ENOENT
    false
  end

  def pid
    File.read(@pid_file).to_i if File.exist?(@pid_file)
  end

  def setup_signal_handlers
    Signal.trap("TERM") do
      puts "Received TERM signal, shutting down gracefully..."
      stop
      exit(0)
    end

    Signal.trap("INT") do
      puts "Received INT signal, shutting down gracefully..."
      stop
      exit(0)
    end
  end

  def start_websocket
    @market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_market_data(tick)
    end

    # Add error handling
    @market_client.on(:error) do |error|
      log_error("WebSocket Error: #{error}")
      @running = false
    end

    @market_client.on(:close) do |close_info|
      log_warning("WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}")
      @running = false
    end

    # Subscribe to indices
    subscribe_to_indices
  end

  def subscribe_to_indices
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      @market_client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      log_info("Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})")
    end
  end

  def process_market_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    data = {
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: timestamp.iso8601,
      name: get_index_name(tick[:segment], tick[:security_id])
    }

    # Log data
    log_info("Market Data: #{data[:name]} = #{data[:ltp]} at #{data[:timestamp]}")

    # Save to file
    save_to_file(data)

    # Send to external service
    send_to_external_service(data)
  end

  def get_index_name(segment, security_id)
    case "#{segment}:#{security_id}"
    when "IDX_I:13" then "NIFTY"
    when "IDX_I:25" then "BANKNIFTY"
    when "IDX_I:29" then "NIFTYIT"
    when "IDX_I:51" then "SENSEX"
    else "#{segment}:#{security_id}"
    end
  end

  def save_to_file(data)
    File.open("/var/log/dhanhq-market-data.json", "a") do |file|
      file.puts(data.to_json)
    end
  end

  def send_to_external_service(data)
    # Example: Send to external API
    # HTTP.post("https://api.example.com/market-data", data.to_json)
  end

  def main_loop
    log_info("Daemon started and running...")
    while @running
      sleep(1)
    end
  end

  def log_info(message)
    log("INFO", message)
  end

  def log_warning(message)
    log("WARN", message)
  end

  def log_error(message)
    log("ERROR", message)
  end

  def log(level, message)
    timestamp = Time.current.iso8601
    log_entry = "[#{timestamp}] #{level}: #{message}\n"

    File.open(@log_file, "a") do |file|
      file.write(log_entry)
    end

    puts log_entry.strip
  end
end

# Command line interface
case ARGV[0]
when "start"
  MarketFeedDaemon.new.start
when "stop"
  MarketFeedDaemon.new.stop
when "status"
  MarketFeedDaemon.new.status
else
  puts "Usage: #{$0} {start|stop|status}"
  exit(1)
end
```

## Command-Line Tools

### Market Data CLI

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'optparse'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class MarketDataCLI
  def initialize
    @options = {}
    @parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"

      opts.on("-m", "--mode MODE", "WebSocket mode (ticker, quote, full)") do |mode|
        @options[:mode] = mode.to_sym
      end

      opts.on("-s", "--symbols SYMBOLS", "Comma-separated list of symbols") do |symbols|
        @options[:symbols] = symbols.split(",")
      end

      opts.on("-o", "--output FILE", "Output file for data") do |file|
        @options[:output] = file
      end

      opts.on("-d", "--duration SECONDS", Integer, "Duration to run (seconds)") do |duration|
        @options[:duration] = duration
      end

      opts.on("-v", "--verbose", "Verbose output") do
        @options[:verbose] = true
      end

      opts.on("-h", "--help", "Show this help") do
        puts opts
        exit
      end
    end
  end

  def run
    @parser.parse!
    @options[:mode] ||= :ticker
    @options[:duration] ||= 30

    case @options[:mode]
    when :ticker
      run_ticker_mode
    when :quote
      run_quote_mode
    when :full
      run_full_mode
    else
      puts "Invalid mode: #{@options[:mode]}"
      puts "Valid modes: ticker, quote, full"
      exit(1)
    end
  end

  private

  def run_ticker_mode
    puts "Starting Market Feed WebSocket (Ticker Mode)..."

    market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_ticker_data(tick)
    end

    # Subscribe to symbols or default indices
    if @options[:symbols]
      subscribe_to_symbols(market_client)
    else
      subscribe_to_default_indices(market_client)
    end

    # Wait for data
    sleep(@options[:duration])

    # Clean shutdown
    market_client.stop
    puts "Market Feed WebSocket stopped."
  end

  def run_quote_mode
    puts "Starting Market Feed WebSocket (Quote Mode)..."

    market_client = DhanHQ::WS.connect(mode: :quote) do |quote|
      process_quote_data(quote)
    end

    # Subscribe to symbols or default indices
    if @options[:symbols]
      subscribe_to_symbols(market_client)
    else
      subscribe_to_default_indices(market_client)
    end

    # Wait for data
    sleep(@options[:duration])

    # Clean shutdown
    market_client.stop
    puts "Market Feed WebSocket stopped."
  end

  def run_full_mode
    puts "Starting Market Feed WebSocket (Full Mode)..."

    market_client = DhanHQ::WS.connect(mode: :full) do |full|
      process_full_data(full)
    end

    # Subscribe to symbols or default indices
    if @options[:symbols]
      subscribe_to_symbols(market_client)
    else
      subscribe_to_default_indices(market_client)
    end

    # Wait for data
    sleep(@options[:duration])

    # Clean shutdown
    market_client.stop
    puts "Market Feed WebSocket stopped."
  end

  def subscribe_to_default_indices(client)
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      puts "✅ Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})"
    end
  end

  def subscribe_to_symbols(client)
    @options[:symbols].each do |symbol|
      # Find the correct segment and security ID
      segment, security_id = find_symbol_info(symbol)
      if segment && security_id
        client.subscribe_one(segment: segment, security_id: security_id)
        puts "✅ Subscribed to #{symbol} (#{segment}:#{security_id})"
      else
        puts "❌ Could not find symbol: #{symbol}"
      end
    end
  end

  def find_symbol_info(symbol)
    # Search in different segments
    segments = ["NSE_EQ", "BSE_EQ", "IDX_I"]

    segments.each do |segment|
      instruments = DhanHQ::Models::Instrument.by_segment(segment)
      instrument = instruments.find { |i| i.symbol_name.upcase.include?(symbol.upcase) }
      return [segment, instrument.security_id] if instrument
    end

    nil
  end

  def process_ticker_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    data = {
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: timestamp.iso8601
    }

    if @options[:verbose]
      puts "📊 Market Data: #{data[:segment]}:#{data[:security_id]} = #{data[:ltp]} at #{data[:timestamp]}"
    end

    save_to_file(data) if @options[:output]
  end

  def process_quote_data(quote)
    timestamp = quote[:ts] ? Time.at(quote[:ts]) : Time.now
    data = {
      segment: quote[:segment],
      security_id: quote[:security_id],
      ltp: quote[:ltp],
      volume: quote[:vol],
      day_high: quote[:day_high],
      day_low: quote[:day_low],
      timestamp: timestamp.iso8601
    }

    if @options[:verbose]
      puts "📊 Quote Data: #{data[:segment]}:#{data[:security_id]}"
      puts "   LTP: #{data[:ltp]}"
      puts "   Volume: #{data[:volume]}"
      puts "   Day High: #{data[:day_high]}"
      puts "   Day Low: #{data[:day_low]}"
      puts "   Timestamp: #{data[:timestamp]}"
    end

    save_to_file(data) if @options[:output]
  end

  def process_full_data(full)
    timestamp = full[:ts] ? Time.at(full[:ts]) : Time.now
    data = {
      segment: full[:segment],
      security_id: full[:security_id],
      ltp: full[:ltp],
      volume: full[:vol],
      day_high: full[:day_high],
      day_low: full[:day_low],
      open: full[:open],
      close: full[:close],
      timestamp: timestamp.iso8601
    }

    if @options[:verbose]
      puts "📊 Full Data: #{data[:segment]}:#{data[:security_id]}"
      puts "   LTP: #{data[:ltp]}"
      puts "   Volume: #{data[:volume]}"
      puts "   Open: #{data[:open]}"
      puts "   High: #{data[:day_high]}"
      puts "   Low: #{data[:day_low]}"
      puts "   Close: #{data[:close]}"
      puts "   Timestamp: #{data[:timestamp]}"
    end

    save_to_file(data) if @options[:output]
  end

  def save_to_file(data)
    File.open(@options[:output], "a") do |file|
      file.puts(data.to_json)
    end
  end
end

# Run the CLI
MarketDataCLI.new.run
```

### Usage Examples

```bash
# Basic usage with default indices
ruby market_data_cli.rb

# Ticker mode for 60 seconds
ruby market_data_cli.rb -m ticker -d 60

# Quote mode with verbose output
ruby market_data_cli.rb -m quote -v

# Full mode with output file
ruby market_data_cli.rb -m full -o market_data.json

# Subscribe to specific symbols
ruby market_data_cli.rb -s "RELIANCE,TCS" -v

# Help
ruby market_data_cli.rb -h
```

## Error Handling

### Comprehensive Error Handling

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class RobustWebSocketClient
  def initialize
    @client = nil
    @running = false
    @retry_count = 0
    @max_retries = 5
    @retry_delay = 5
  end

  def start
    @running = true
    connect_with_retry
  end

  def stop
    @running = false
    @client&.stop
  end

  private

  def connect_with_retry
    while @running && @retry_count < @max_retries
      begin
        connect
        @retry_count = 0  # Reset retry count on successful connection
        wait_for_connection
      rescue StandardError => e
        handle_connection_error(e)
      end
    end

    if @retry_count >= @max_retries
      puts "❌ Maximum retry attempts reached. Giving up."
      @running = false
    end
  end

  def connect
    puts "🔄 Attempting to connect (attempt #{@retry_count + 1}/#{@max_retries})..."

    @client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_data(tick)
    end

    # Add comprehensive error handling
    @client.on(:error) do |error|
      puts "❌ WebSocket Error: #{error}"
      handle_websocket_error(error)
    end

    @client.on(:close) do |close_info|
      puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
      handle_websocket_close(close_info)
    end

    # Subscribe to indices
    subscribe_to_indices
  end

  def subscribe_to_indices
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      @client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      puts "✅ Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})"
    end
  end

  def process_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    data = {
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: timestamp.iso8601
    }

    puts "📊 Market Data: #{data[:segment]}:#{data[:security_id]} = #{data[:ltp]} at #{data[:timestamp]}"
  end

  def wait_for_connection
    puts "✅ Connected successfully. Waiting for data..."
    while @running
      sleep(1)
    end
  end

  def handle_connection_error(error)
    @retry_count += 1
    puts "❌ Connection error: #{error.class} - #{error.message}"
    puts "🔄 Retrying in #{@retry_delay} seconds..."
    sleep(@retry_delay)
  end

  def handle_websocket_error(error)
    puts "❌ WebSocket error: #{error}"
    # Don't increment retry count for WebSocket errors
    # The connection will be closed and we'll retry
  end

  def handle_websocket_close(close_info)
    puts "🔌 WebSocket closed: #{close_info[:code]} - #{close_info[:reason]}"

    # Handle specific close codes
    case close_info[:code]
    when 1006
      puts "🔄 Connection lost, will retry..."
    when 1000
      puts "✅ Normal closure"
      @running = false
    when 1001
      puts "🔄 Going away, will retry..."
    when 1002
      puts "❌ Protocol error, will retry..."
    when 1003
      puts "❌ Unsupported data, will retry..."
    when 1004
      puts "❌ Reserved, will retry..."
    when 1005
      puts "❌ No status received, will retry..."
    when 1007
      puts "❌ Invalid frame payload data, will retry..."
    when 1008
      puts "❌ Policy violation, will retry..."
    when 1009
      puts "❌ Message too big, will retry..."
    when 1010
      puts "❌ Missing extension, will retry..."
    when 1011
      puts "❌ Internal error, will retry..."
    when 1012
      puts "🔄 Service restart, will retry..."
    when 1013
      puts "🔄 Try again later, will retry..."
    when 1014
      puts "❌ Bad gateway, will retry..."
    when 1015
      puts "❌ TLS handshake, will retry..."
    else
      puts "❌ Unknown close code: #{close_info[:code]}, will retry..."
    end
  end
end

# Run the robust client
client = RobustWebSocketClient.new

# Handle interrupt signals
Signal.trap("INT") do
  puts "\n🛑 Received interrupt signal, shutting down..."
  client.stop
  exit(0)
end

Signal.trap("TERM") do
  puts "\n🛑 Received terminate signal, shutting down..."
  client.stop
  exit(0)
end

client.start
```

## Production Considerations

### Logging

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'logger'
require 'json'

# Configure logging
logger = Logger.new(STDOUT)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    level: severity,
    message: msg,
    service: 'dhanhq-websocket'
  }.to_json + "\n"
end

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
  config.logger = logger
end

class ProductionWebSocketClient
  def initialize
    @client = nil
    @running = false
    @logger = logger
  end

  def start
    @running = true
    @logger.info("Starting WebSocket client")

    @client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_data(tick)
    end

    # Add error handling
    @client.on(:error) do |error|
      @logger.error("WebSocket error: #{error}")
    end

    @client.on(:close) do |close_info|
      @logger.warn("WebSocket closed: #{close_info[:code]} - #{close_info[:reason]}")
    end

    # Subscribe to indices
    subscribe_to_indices

    # Wait for data
    wait_for_data
  end

  def stop
    @running = false
    @client&.stop
    @logger.info("WebSocket client stopped")
  end

  private

  def subscribe_to_indices
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      @client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      @logger.info("Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})")
    end
  end

  def process_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    data = {
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: timestamp.iso8601
    }

    @logger.info("Market data received: #{data[:segment]}:#{data[:security_id]} = #{data[:ltp]}")

    # Save to file
    save_to_file(data)
  end

  def save_to_file(data)
    File.open("/var/log/dhanhq-market-data.json", "a") do |file|
      file.puts(data.to_json)
    end
  end

  def wait_for_data
    @logger.info("Waiting for market data...")
    while @running
      sleep(1)
    end
  end
end

# Run the production client
client = ProductionWebSocketClient.new

# Handle interrupt signals
Signal.trap("INT") do
  client.stop
  exit(0)
end

Signal.trap("TERM") do
  client.stop
  exit(0)
end

client.start
```

### Monitoring

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dhan_hq'
require 'json'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

class WebSocketMonitor
  def initialize
    @clients = {}
    @stats = {
      total_messages: 0,
      errors: 0,
      reconnections: 0,
      start_time: Time.current
    }
  end

  def start_monitoring
    puts "🔍 Starting WebSocket monitoring..."

    # Start market feed client
    start_market_feed_client

    # Start order update client
    start_order_update_client

    # Start market depth client
    start_market_depth_client

    # Monitor loop
    monitor_loop
  end

  def stop_monitoring
    puts "🛑 Stopping WebSocket monitoring..."
    @clients.each_value(&:stop)
  end

  private

  def start_market_feed_client
    @clients[:market_feed] = DhanHQ::WS.connect(mode: :ticker) do |tick|
      @stats[:total_messages] += 1
      process_market_data(tick)
    end

    @clients[:market_feed].on(:error) do |error|
      @stats[:errors] += 1
      puts "❌ Market Feed Error: #{error}"
    end

    @clients[:market_feed].on(:close) do |close_info|
      @stats[:reconnections] += 1
      puts "🔌 Market Feed Closed: #{close_info[:code]}"
    end

    # Subscribe to indices
    subscribe_to_indices(@clients[:market_feed])
  end

  def start_order_update_client
    @clients[:order_updates] = DhanHQ::WS::Orders.connect do |order_update|
      @stats[:total_messages] += 1
      process_order_update(order_update)
    end

    @clients[:order_updates].on(:error) do |error|
      @stats[:errors] += 1
      puts "❌ Order Update Error: #{error}"
    end

    @clients[:order_updates].on(:close) do |close_info|
      @stats[:reconnections] += 1
      puts "🔌 Order Update Closed: #{close_info[:code]}"
    end
  end

  def start_market_depth_client
    symbols = [
      { symbol: "RELIANCE", exchange_segment: "NSE_EQ", security_id: "2885" },
      { symbol: "TCS", exchange_segment: "NSE_EQ", security_id: "11536" }
    ]

    @clients[:market_depth] = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
      @stats[:total_messages] += 1
      process_market_depth(depth_data)
    end

    @clients[:market_depth].on(:error) do |error|
      @stats[:errors] += 1
      puts "❌ Market Depth Error: #{error}"
    end

    @clients[:market_depth].on(:close) do |close_info|
      @stats[:reconnections] += 1
      puts "🔌 Market Depth Closed: #{close_info[:code]}"
    end
  end

  def subscribe_to_indices(client)
    indices = [
      { segment: "IDX_I", security_id: "13", name: "NIFTY" },
      { segment: "IDX_I", security_id: "25", name: "BANKNIFTY" },
      { segment: "IDX_I", security_id: "29", name: "NIFTYIT" },
      { segment: "IDX_I", security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      puts "✅ Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})"
    end
  end

  def process_market_data(tick)
    timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
    puts "📊 Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
  end

  def process_order_update(order_update)
    puts "📝 Order Update: #{order_update.order_no} - #{order_update.status}"
  end

  def process_market_depth(depth_data)
    puts "📊 Market Depth: #{depth_data[:symbol]} - Bid: #{depth_data[:best_bid]}, Ask: #{depth_data[:best_ask]}"
  end

  def monitor_loop
    puts "🔍 Monitoring WebSocket connections..."
    puts "Press Ctrl+C to stop"

    begin
      while true
        sleep(30)  # Print stats every 30 seconds
        print_stats
      end
    rescue Interrupt
      puts "\n🛑 Received interrupt signal, shutting down..."
      stop_monitoring
    end
  end

  def print_stats
    uptime = Time.current - @stats[:start_time]
    puts "\n📊 WebSocket Statistics:"
    puts "   Uptime: #{uptime.round(2)} seconds"
    puts "   Total Messages: #{@stats[:total_messages]}"
    puts "   Errors: #{@stats[:errors]}"
    puts "   Reconnections: #{@stats[:reconnections]}"
    puts "   Messages/sec: #{(@stats[:total_messages] / uptime).round(2)}"
    puts "   Error Rate: #{(@stats[:errors].to_f / @stats[:total_messages] * 100).round(2)}%"
    puts "   ---"
  end
end

# Run the monitor
monitor = WebSocketMonitor.new
monitor.start_monitoring
```

## Best Practices

### 1. Configuration Management

- Use environment variables for credentials
- Implement configuration validation
- Use different configurations for different environments

### 2. Error Handling

- Implement comprehensive error handling
- Log all errors with context
- Implement retry logic with exponential backoff
- Handle connection failures gracefully

### 3. Resource Management

- Always clean up WebSocket connections
- Implement proper signal handling
- Monitor memory usage
- Clean up old data regularly

### 4. Performance

- Use background processing for heavy operations
- Implement caching for frequently accessed data
- Monitor connection count and rate limits
- Optimize data processing

### 5. Security

- Never log sensitive information
- Use secure credential storage
- Implement proper authentication
- Monitor for suspicious activity

### 6. Monitoring

- Implement health checks
- Monitor connection status
- Track error rates and reconnections
- Set up alerts for critical issues

This comprehensive standalone Ruby integration guide provides everything needed to integrate DhanHQ WebSocket connections into standalone Ruby applications with production-ready patterns and best practices.
