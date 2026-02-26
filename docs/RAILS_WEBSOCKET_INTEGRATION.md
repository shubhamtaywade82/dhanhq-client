# Rails WebSocket Integration Guide

This guide provides comprehensive instructions for integrating DhanHQ WebSocket connections into Rails applications, including best practices, service patterns, and production considerations.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Service Patterns](#service-patterns)
4. [Background Processing](#background-processing)
5. [ActionCable Integration](#actioncable-integration)
6. [Production Considerations](#production-considerations)
7. [Monitoring & Debugging](#monitoring--debugging)
8. [Best Practices](#best-practices)

## Quick Start

### 1. Add to Gemfile

```ruby
# Gemfile
gem 'dhan_hq'
```

### 2. Configure DhanHQ

```ruby
# config/initializers/dhan_hq.rb
DhanHQ.configure do |config|
  config.client_id = Rails.application.credentials.dhanhq[:client_id]
  config.access_token = Rails.application.credentials.dhanhq[:access_token]
  config.ws_user_type = Rails.application.credentials.dhanhq[:ws_user_type] || "SELF"
end
```

### 3. Set up Credentials

```bash
# Add credentials
rails credentials:edit

# Add the following:
dhanhq:
  client_id: your_client_id
  access_token: your_access_token
  ws_user_type: SELF
```

### 4. Create a Service

```ruby
# app/services/market_data_service.rb
class MarketDataService
  def initialize
    @market_client = nil
  end

  def start_market_feed
    @market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_market_data(tick)
    end

    # Subscribe to major indices
    @market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "13")  # NIFTY
    @market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "25")  # BANKNIFTY
    @market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "29")  # NIFTYIT
    @market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "51")  # SENSEX
  end

  def stop_market_feed
    @market_client&.stop
    @market_client = nil
  end

  private

  def process_market_data(tick)
    # Store in database
    MarketData.create!(
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: tick[:ts] ? Time.at(tick[:ts]) : Time.now
    )

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      "market_data_#{tick[:segment]}",
      {
        segment: tick[:segment],
        security_id: tick[:security_id],
        ltp: tick[:ltp],
        timestamp: tick[:ts]
      }
    )
  end
end
```

## Configuration

For dynamic token use `config.access_token_provider`. For web-generated tokens refresh with `DhanHQ::Auth.renew_token(access_token, client_id)`. API key/Partner flows: implement in your app. See [AUTHENTICATION.md](AUTHENTICATION.md).

### Environment-Specific Configuration

```ruby
# config/initializers/dhan_hq.rb
DhanHQ.configure do |config|
  if Rails.env.production?
    config.client_id = Rails.application.credentials.dhanhq[:client_id]
    config.access_token = Rails.application.credentials.dhanhq[:access_token]
  else
    config.client_id = ENV["DHAN_CLIENT_ID"] || "your_client_id"
    config.access_token = ENV["DHAN_ACCESS_TOKEN"] || "your_access_token"
  end

  config.ws_user_type = Rails.application.credentials.dhanhq[:ws_user_type] || "SELF"

  # Use Rails logger
  config.logger = Rails.logger
end
```

### Development Configuration

```ruby
# config/environments/development.rb
Rails.application.configure do
  # Enable WebSocket debugging
  config.log_level = :debug

  # Configure ActionCable for WebSocket testing
  config.action_cable.allowed_request_origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000"
  ]
end
```

### Production Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Use structured logging
  config.log_level = :info

  # Configure ActionCable for production
  config.action_cable.allowed_request_origins = [
    "https://yourdomain.com"
  ]
end
```

## Service Patterns

### Market Data Service

```ruby
# app/services/market_data_service.rb
class MarketDataService
  include Singleton

  def initialize
    @market_client = nil
    @running = false
  end

  def start_market_feed
    return if @running

    @running = true
    @market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_market_data(tick)
    end

    # Add error handling
    @market_client.on(:error) do |error|
      Rails.logger.error "Market WebSocket error: #{error}"
      @running = false
    end

    @market_client.on(:close) do |close_info|
      Rails.logger.warn "Market WebSocket closed: #{close_info[:code]}"
      @running = false
    end

    # Subscribe to indices
    subscribe_to_indices
  end

  def stop_market_feed
    @running = false
    @market_client&.stop
    @market_client = nil
  end

  def running?
    @running && @market_client&.connected?
  end

  private

  def subscribe_to_indices
    indices = [
      { segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "13", name: "NIFTY" },
      { segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "25", name: "BANKNIFTY" },
      { segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "29", name: "NIFTYIT" },
      { segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "51", name: "SENSEX" }
    ]

    indices.each do |index|
      @market_client.subscribe_one(
        segment: index[:segment],
        security_id: index[:security_id]
      )
      Rails.logger.info "Subscribed to #{index[:name]} (#{index[:segment]}:#{index[:security_id]})"
    end
  end

  def process_market_data(tick)
    # Store in database
    market_data = MarketData.create!(
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: tick[:ts] ? Time.at(tick[:ts]) : Time.now
    )

    # Update cache
    cache_key = "market_data_#{tick[:segment]}:#{tick[:security_id]}"
    Rails.cache.write(cache_key, market_data, expires_in: 1.minute)

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      "market_data_#{tick[:segment]}",
      {
        segment: tick[:segment],
        security_id: tick[:security_id],
        ltp: tick[:ltp],
        timestamp: tick[:ts],
        name: get_index_name(tick[:segment], tick[:security_id])
      }
    )

    # Trigger background job for additional processing
    ProcessMarketDataJob.perform_later(market_data)
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
end
```

### Order Update Service

```ruby
# app/services/order_update_service.rb
class OrderUpdateService
  include Singleton

  def initialize
    @orders_client = nil
    @running = false
  end

  def start_order_updates
    return if @running

    @running = true
    @orders_client = DhanHQ::WS::Orders.connect do |order_update|
      process_order_update(order_update)
    end

    # Add comprehensive event handling
    @orders_client.on(:update) do |order_update|
      Rails.logger.info "Order updated: #{order_update.order_no} - #{order_update.status}"
    end

    @orders_client.on(:status_change) do |change_data|
      Rails.logger.info "Order status changed: #{change_data[:previous_status]} -> #{change_data[:new_status]}"
    end

    @orders_client.on(:execution) do |execution_data|
      Rails.logger.info "Order executed: #{execution_data[:new_traded_qty]} shares"
    end

    @orders_client.on(:order_traded) do |order_update|
      Rails.logger.info "Order traded: #{order_update.order_no} - #{order_update.symbol}"
    end

    @orders_client.on(:order_rejected) do |order_update|
      Rails.logger.error "Order rejected: #{order_update.order_no} - #{order_update.reason_description}"
    end

    @orders_client.on(:error) do |error|
      Rails.logger.error "Order WebSocket error: #{error}"
      @running = false
    end

    @orders_client.on(:close) do |close_info|
      Rails.logger.warn "Order WebSocket closed: #{close_info[:code]}"
      @running = false
    end
  end

  def stop_order_updates
    @running = false
    @orders_client&.stop
    @orders_client = nil
  end

  def running?
    @running && @orders_client&.connected?
  end

  private

  def process_order_update(order_update)
    # Update database
    order = Order.find_by(order_no: order_update.order_no)
    if order
      order.update!(
        status: order_update.status,
        traded_qty: order_update.traded_qty,
        avg_price: order_update.avg_traded_price,
        execution_percentage: order_update.execution_percentage
      )

      # Broadcast to user
      ActionCable.server.broadcast(
        "order_updates_#{order.user_id}",
        {
          order_no: order_update.order_no,
          status: order_update.status,
          traded_qty: order_update.traded_qty,
          execution_percentage: order_update.execution_percentage,
          symbol: order_update.symbol,
          price: order_update.price
        }
      )

      # Trigger background job for additional processing
      ProcessOrderUpdateJob.perform_later(order_update)
    end
  end
end
```

### Market Depth Service

```ruby
# app/services/market_depth_service.rb
class MarketDepthService
  include Singleton

  def initialize
    @depth_client = nil
    @running = false
  end

  def start_market_depth(symbols = nil)
    return if @running

    @running = true
    symbols ||= default_symbols

    @depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
      process_market_depth(depth_data)
    end

    # Add error handling
    @depth_client.on(:error) do |error|
      Rails.logger.error "Market Depth WebSocket error: #{error}"
      @running = false
    end

    @depth_client.on(:close) do |close_info|
      Rails.logger.warn "Market Depth WebSocket closed: #{close_info[:code]}"
      @running = false
    end
  end

  def stop_market_depth
    @running = false
    @depth_client&.stop
    @depth_client = nil
  end

  def running?
    @running && @depth_client&.connected?
  end

  private

  def default_symbols
    [
      { symbol: "RELIANCE", exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, security_id: "2885" },
      { symbol: "TCS", exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, security_id: "11536" }
    ]
  end

  def process_market_depth(depth_data)
    # Store in database
    market_depth = MarketDepth.create!(
      symbol: depth_data[:symbol],
      exchange_segment: depth_data[:exchange_segment],
      security_id: depth_data[:security_id],
      best_bid: depth_data[:best_bid],
      best_ask: depth_data[:best_ask],
      spread: depth_data[:spread],
      bid_levels: depth_data[:bids],
      ask_levels: depth_data[:asks],
      timestamp: Time.current
    )

    # Update cache
    cache_key = "market_depth_#{depth_data[:symbol]}"
    Rails.cache.write(cache_key, market_depth, expires_in: 30.seconds)

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      "market_depth_#{depth_data[:symbol]}",
      {
        symbol: depth_data[:symbol],
        best_bid: depth_data[:best_bid],
        best_ask: depth_data[:best_ask],
        spread: depth_data[:spread],
        bid_levels: depth_data[:bids],
        ask_levels: depth_data[:asks],
        timestamp: Time.current
      }
    )

    # Trigger background job for additional processing
    ProcessMarketDepthJob.perform_later(market_depth)
  end
end
```

## Background Processing

### Market Data Processing Job

```ruby
# app/jobs/process_market_data_job.rb
class ProcessMarketDataJob < ApplicationJob
  queue_as :market_data

  def perform(market_data)
    # Update real-time cache
    Rails.cache.write(
      "realtime_#{market_data.segment}:#{market_data.security_id}",
      market_data,
      expires_in: 1.minute
    )

    # Update user portfolios if needed
    update_user_portfolios(market_data)

    # Send notifications for significant price movements
    check_price_alerts(market_data)
  end

  private

  def update_user_portfolios(market_data)
    # Update portfolio values for users holding this instrument
    Portfolio.where(segment: market_data.segment, security_id: market_data.security_id)
             .find_each do |portfolio|
      portfolio.update_current_value(market_data.ltp)
    end
  end

  def check_price_alerts(market_data)
    # Check for price alerts
    PriceAlert.where(segment: market_data.segment, security_id: market_data.security_id)
              .where("target_price <= ?", market_data.ltp)
              .find_each do |alert|
      PriceAlertNotificationJob.perform_later(alert, market_data)
    end
  end
end
```

### Order Update Processing Job

```ruby
# app/jobs/process_order_update_job.rb
class ProcessOrderUpdateJob < ApplicationJob
  queue_as :order_updates

  def perform(order_update)
    # Update order history
    OrderHistory.create!(
      order_no: order_update.order_no,
      status: order_update.status,
      traded_qty: order_update.traded_qty,
      avg_price: order_update.avg_traded_price,
      execution_percentage: order_update.execution_percentage,
      timestamp: Time.current
    )

    # Update user's trading statistics
    update_trading_stats(order_update)

    # Send email notifications for completed orders
    send_order_completion_email(order_update) if order_update.fully_executed?
  end

  private

  def update_trading_stats(order_update)
    user = User.joins(:orders).find_by(orders: { order_no: order_update.order_no })
    return unless user

    user.trading_stats.increment!(:total_trades) if order_update.fully_executed?
    user.trading_stats.increment!(:total_volume, order_update.traded_qty)
  end

  def send_order_completion_email(order_update)
    user = User.joins(:orders).find_by(orders: { order_no: order_update.order_no })
    return unless user

    OrderCompletionMailer.order_completed(user, order_update).deliver_later
  end
end
```

## ActionCable Integration

### Market Data Channel

```ruby
# app/channels/market_data_channel.rb
class MarketDataChannel < ApplicationCable::Channel
  def subscribed
    stream_from "market_data_#{params[:segment]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def receive(data)
    # Handle any data sent from the client
  end
end
```

### Order Updates Channel

```ruby
# app/channels/order_updates_channel.rb
class OrderUpdatesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "order_updates_#{current_user.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
```

### Market Depth Channel

```ruby
# app/channels/market_depth_channel.rb
class MarketDepthChannel < ApplicationCable::Channel
  def subscribed
    stream_from "market_depth_#{params[:symbol]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
```

### JavaScript Client

```javascript
// app/assets/javascripts/channels/market_data.js
import consumer from "./consumer"

consumer.subscriptions.create("MarketDataChannel", {
  connected() {
    console.log("Connected to market data channel")
  },

  disconnected() {
    console.log("Disconnected from market data channel")
  },

  received(data) {
    console.log("Market data received:", data)
    updateMarketDataDisplay(data)
  }
})

function updateMarketDataDisplay(data) {
  const element = document.getElementById(`market-data-${data.segment}-${data.security_id}`)
  if (element) {
    element.textContent = data.ltp
    element.classList.add('updated')
    setTimeout(() => element.classList.remove('updated'), 1000)
  }
}
```

## Production Considerations

### Application Controller Integration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :ensure_websocket_cleanup

  private

  def ensure_websocket_cleanup
    yield
  ensure
    # Clean up any stray WebSocket connections
    DhanHQ::WS.disconnect_all_local!
  end
end
```

### Initializer for Production

```ruby
# config/initializers/websocket_services.rb
Rails.application.config.after_initialize do
  # Start WebSocket services in production
  if Rails.env.production?
    # Start market data service
    MarketDataService.instance.start_market_feed

    # Start order update service
    OrderUpdateService.instance.start_order_updates

    # Start market depth service
    MarketDepthService.instance.start_market_depth
  end
end
```

### Graceful Shutdown

```ruby
# config/initializers/graceful_shutdown.rb
Rails.application.config.after_initialize do
  # Handle graceful shutdown
  Signal.trap("TERM") do
    Rails.logger.info "Received TERM signal, shutting down gracefully..."

    # Stop WebSocket services
    MarketDataService.instance.stop_market_feed
    OrderUpdateService.instance.stop_order_updates
    MarketDepthService.instance.stop_market_depth

    # Disconnect all WebSocket connections
    DhanHQ::WS.disconnect_all_local!

    Rails.logger.info "Graceful shutdown completed"
    exit(0)
  end

  Signal.trap("INT") do
    Rails.logger.info "Received INT signal, shutting down gracefully..."

    # Stop WebSocket services
    MarketDataService.instance.stop_market_feed
    OrderUpdateService.instance.stop_order_updates
    MarketDepthService.instance.stop_market_depth

    # Disconnect all WebSocket connections
    DhanHQ::WS.disconnect_all_local!

    Rails.logger.info "Graceful shutdown completed"
    exit(0)
  end
end
```

### Health Check Endpoint

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def websocket_status
    render json: {
      market_data: {
        running: MarketDataService.instance.running?,
        connected: MarketDataService.instance.running?
      },
      order_updates: {
        running: OrderUpdateService.instance.running?,
        connected: OrderUpdateService.instance.running?
      },
      market_depth: {
        running: MarketDepthService.instance.running?,
        connected: MarketDepthService.instance.running?
      }
    }
  end
end
```

## Monitoring & Debugging

### Logging Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Structured logging for WebSocket events
  config.log_formatter = proc do |severity, datetime, progname, msg|
    {
      timestamp: datetime,
      level: severity,
      message: msg,
      service: 'dhanhq-websocket'
    }.to_json + "\n"
  end
end
```

### Custom Logger

```ruby
# app/services/websocket_logger.rb
class WebSocketLogger
  def self.log_event(event_type, data)
    Rails.logger.info({
      event: event_type,
      data: data,
      timestamp: Time.current,
      service: 'dhanhq-websocket'
    }.to_json)
  end
end
```

### Monitoring Dashboard

```ruby
# app/controllers/admin/websocket_monitor_controller.rb
class Admin::WebsocketMonitorController < ApplicationController
  before_action :authenticate_admin!

  def index
    @market_data_status = MarketDataService.instance.running?
    @order_updates_status = OrderUpdateService.instance.running?
    @market_depth_status = MarketDepthService.instance.running?

    @recent_market_data = MarketData.order(created_at: :desc).limit(100)
    @recent_order_updates = OrderHistory.order(created_at: :desc).limit(100)
  end

  def restart_services
    # Restart WebSocket services
    MarketDataService.instance.stop_market_feed
    MarketDataService.instance.start_market_feed

    OrderUpdateService.instance.stop_order_updates
    OrderUpdateService.instance.start_order_updates

    MarketDepthService.instance.stop_market_depth
    MarketDepthService.instance.start_market_depth

    redirect_to admin_websocket_monitor_index_path, notice: 'WebSocket services restarted'
  end
end
```

## Best Practices

### 1. Service Management

- Use singleton pattern for WebSocket services
- Implement proper start/stop methods
- Add health check endpoints
- Monitor service status

### 2. Error Handling

- Implement comprehensive error handling
- Log all WebSocket events
- Handle connection failures gracefully
- Implement retry logic

### 3. Performance

- Use background jobs for heavy processing
- Implement caching for frequently accessed data
- Monitor memory usage
- Clean up old data regularly

### 4. Security

- Use environment variables for credentials
- Implement proper authentication for channels
- Sanitize all user inputs
- Monitor for suspicious activity

### 5. Testing

```ruby
# spec/services/market_data_service_spec.rb
RSpec.describe MarketDataService do
  let(:service) { MarketDataService.instance }

  before do
    service.stop_market_feed
  end

  after do
    service.stop_market_feed
  end

  describe '#start_market_feed' do
    it 'starts the market feed successfully' do
      expect { service.start_market_feed }.not_to raise_error
      expect(service.running?).to be true
    end
  end

  describe '#stop_market_feed' do
    it 'stops the market feed successfully' do
      service.start_market_feed
      service.stop_market_feed
      expect(service.running?).to be false
    end
  end
end
```

This comprehensive Rails integration guide provides everything needed to integrate DhanHQ WebSocket connections into Rails applications with production-ready patterns and best practices.
