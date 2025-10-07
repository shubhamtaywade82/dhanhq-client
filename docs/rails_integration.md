# Rails Integration Guide for DhanHQ

This guide demonstrates how to wire the `DhanHQ` Ruby client into a Rails
application so you can automate trading flows, fetch data, and stream market
updates via WebSockets. The examples assume Rails 7+, but the concepts apply to
older versions as well.

## 1. Install the gem

Add the gem to your Rails application's `Gemfile` and bundle:

```ruby
# Gemfile
gem 'DhanHQ', git: 'https://github.com/shubhamtaywade82/dhanhq-client.git', branch: 'main'
```

```bash
bundle install
```

If you package the gem privately you can also point to a released version from
RubyGems.

## 2. Configure credentials & initializer

Store the Dhan client id and access token using Rails credentials or ENV
variables. These two keys are **required** for `DhanHQ.configure_with_env` to
boot successfully:

| Variable | Description |
| --- | --- |
| `CLIENT_ID` | Dhan trading client id for the account you want to trade with. |
| `ACCESS_TOKEN` | REST/WebSocket access token (regenerate via the Dhan console or APIs). |

```bash
bin/rails credentials:edit
```

```yaml
dhanhq:
  client_id: "1001234567"
  access_token: "eyJhbGciOi..."
  log_level: "info"         # optional
  base_url: "https://api.dhan.co/v2"              # optional
  ws_order_url: "wss://api-order-update.dhan.co"  # optional
  ws_user_type: "SELF"                            # optional (SELF or PARTNER)
  partner_id: "your-partner-id"                   # optional when ws_user_type: PARTNER
  partner_secret: "your-partner-secret"           # optional when ws_user_type: PARTNER
```

Create an initializer so your app boots with the correct configuration via
environment variables (Rails credentials can be copied into ENV on boot):

```ruby
# config/initializers/dhanhq.rb
require 'DhanHQ'

if (creds = Rails.application.credentials.dig(:dhanhq))
  ENV['CLIENT_ID']        ||= creds[:client_id]
  ENV['ACCESS_TOKEN']     ||= creds[:access_token]
  ENV['DHAN_LOG_LEVEL']   ||= creds[:log_level]&.upcase
  ENV['DHAN_BASE_URL']    ||= creds[:base_url]
  ENV['DHAN_WS_ORDER_URL'] ||= creds[:ws_order_url]
  ENV['DHAN_WS_USER_TYPE'] ||= creds[:ws_user_type]
  ENV['DHAN_PARTNER_ID']    ||= creds[:partner_id]
  ENV['DHAN_PARTNER_SECRET'] ||= creds[:partner_secret]
end

# fall back to traditional ENV variables when credentials are not defined
ENV['CLIENT_ID']    ||= ENV.fetch('DHAN_CLIENT_ID', nil)
ENV['ACCESS_TOKEN'] ||= ENV.fetch('DHAN_ACCESS_TOKEN', nil)

DhanHQ.configure_with_env

log_level = (ENV['DHAN_LOG_LEVEL'] || 'INFO').upcase
DhanHQ.logger.level = Logger.const_get(log_level)
```

**Optional configuration**

Populate any of the following keys when you need to override the gem defaults
or enable partner streaming flows:

| Variable | Purpose |
| --- | --- |
| `DHAN_LOG_LEVEL` | Change the logger level (`INFO` default). |
| `DHAN_BASE_URL` | Target a different REST API host. |
| `DHAN_WS_VERSION` | Pin WebSocket connections to a specific API version. |
| `DHAN_WS_ORDER_URL` | Override the order update WebSocket endpoint. |
| `DHAN_WS_USER_TYPE` | Switch between `SELF` and `PARTNER` WebSocket auth. |
| `DHAN_PARTNER_ID` / `DHAN_PARTNER_SECRET` | Required when `DHAN_WS_USER_TYPE=PARTNER`. |

Set the variables in ENV (or in credentials copied to ENV) **before** the
initializer calls `DhanHQ.configure_with_env`.

## 3. Build service objects for REST flows

Wrap trading actions in plain-old Ruby objects so controllers and jobs stay thin:

```ruby
# app/services/dhan/orders/place_order.rb
module Dhan
  module Orders
    class PlaceOrder
      def initialize(params)
        @params = params
      end

      def call
        order = DhanHQ::Models::Order.new(@params)
        order.save
        order
      rescue DhanHQ::Error => e
        Rails.logger.error("Dhan order failed: #{e.message}")
        raise
      end
    end
  end
end
```

Use the service from controllers, background jobs, or scheduled tasks:

```ruby
class OrdersController < ApplicationController
  def create
    order = Dhan::Orders::PlaceOrder.new(order_params).call
    render json: order.attributes
  end

  private

  def order_params
    params.require(:order).permit(:transaction_type, :exchange_segment, :product_type,
                                  :order_type, :validity, :security_id, :quantity,
                                  :price, :trigger_price, :correlation_id)
  end
end
```

The gem exposes models for positions, holdings, trades, funds, option chains,
historical bars, etc. Instantiate them the same way (`Model.all`, `.find`,
`.where`, `#save`).

## 4. Centralise error handling

Wrap the gem's exceptions in a concern so Rails controllers and jobs return
consistent responses:

```ruby
# app/controllers/concerns/handles_dhan_errors.rb
module HandlesDhanErrors
  extend ActiveSupport::Concern

  included do
    rescue_from DhanHQ::Error, with: :render_dhan_error
  end

  private

  def render_dhan_error(error)
    Rails.logger.warn("Dhan API error: #{error.message}")
    render json: { error: error.message, details: error.details }, status: :unprocessable_entity
  end
end
```

Include the concern in API controllers or base controllers as needed.

## 5. Consume market data via WebSockets

The gem ships with an EventMachine-based client that can run inside your Rails
processes. The simplest approach is to start a dedicated process (e.g. a
Sidekiq worker or a Rails runner) that keeps the connection alive and publishes
ticks through ActionCable, Redis, or a database.

```ruby
# app/workers/dhan/market_feed_worker.rb
class Dhan::MarketFeedWorker
  include Sidekiq::Worker

  def perform(mode = :quote, securities = [])
    client = DhanHQ::WS::Client.new(mode: mode.to_sym)

    client.on(:open) { Rails.logger.info('Dhan WS connected') }
    client.on(:close) { Rails.logger.warn('Dhan WS closed; worker will retry') }
    client.on(:error) { |err| Rails.logger.error("Dhan WS error: #{err}") }

    client.on(:tick) do |tick|
      ActionCable.server.broadcast('market_feed', tick)
    end

    client.start
    client.subscribe(securities) if securities.any?
    client.wait! # blocks the worker thread while EventMachine runs
  end
end
```

Schedule the worker from `sidekiq.yml`, a scheduler, or run on demand:

```bash
bundle exec sidekiq -q default
bundle exec sidekiq-client push '{"class":"Dhan::MarketFeedWorker","args":["quote",[["NSE_EQ","1333"]]]}'
```

Define an ActionCable channel so browsers receive updates in real time:

```ruby
# app/channels/market_feed_channel.rb
class MarketFeedChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'market_feed'
  end
end
```

## 6. Stream order updates

Use the order-update WebSocket endpoint (configure `ws_order_url` and
`ws_user_type`) and process callbacks similarly:

```ruby
# app/workers/dhan/order_updates_worker.rb
class Dhan::OrderUpdatesWorker
  include Sidekiq::Worker

  def perform
    client = DhanHQ::WS::Client.new(kind: :order_updates)

    client.on(:order_update) do |payload|
      OrderStatusUpdater.call(payload)
    end

    client.on(:error) { |err| Rails.logger.error("Dhan order WS error: #{err}") }

    client.start
    client.wait!
  end
end
```

Inside `OrderStatusUpdater` you can reconcile the payload with your local order
records, notify users via ActionCable or email, etc.

## 7. Schedule automation & backfills

Leverage ActiveJob, Sidekiq, or any scheduler (Whenever, Clockwork, Cron) to run
recurring jobs that pull data or enforce trading rules:

```ruby
# app/jobs/dhan/refresh_positions_job.rb
class Dhan::RefreshPositionsJob < ApplicationJob
  queue_as :default

  def perform
    positions = DhanHQ::Models::Position.all
    positions.each { |position| PositionSync.call(position) }
  end
end
```

Trigger from cron using `whenever`:

```ruby
# config/schedule.rb
every 5.minutes do
  runner 'Dhan::RefreshPositionsJob.perform_later'
end
```

## 8. Testing helpers

For tests, stub HTTP requests using WebMock or VCR. The client delegates all
REST calls through Faraday, so you can match on URLs under
`https://api.dhan.co/v2`. For WebSockets, inject a fake transport by stubbing
`DhanHQ::WS::Connection`.

```ruby
# spec/support/dhanhq.rb
RSpec.configure do |config|
  config.before(:each, dhan: true) do
    stub_request(:post, %r{https://api\.dhan\.co/v2/orders}).to_return(
      status: 200,
      body: { status: 'success', order_id: '123' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end
```

## 9. Deployment notes

- Run WebSocket consumers outside the web dynos/processes so Puma/Passenger
  threads are not blocked.
- Ensure the `access_token` is refreshed before expiry; wire a cron job or
  admin panel action that updates the stored token and restarts workers.
- Monitor the gem's logger output for `429` or `503` responses to adjust retry
  logic.

## 10. Further reading

- [GUIDE.md](../GUIDE.md) — in-depth overview of the gem's models and APIs.
- [README.md](../README.md) — quick start, features, and WebSocket usage.
