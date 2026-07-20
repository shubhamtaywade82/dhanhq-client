---
name: dhanhq-ruby
description: >
  Use when the user mentions DhanHQ, Dhan API, or wants to trade on
  Indian exchanges (NSE, BSE, MCX) using Ruby. Triggers for: place, modify, or
  cancel stock/F&O/commodity orders on Dhan using Ruby; fetch portfolio holdings
  or positions; get live or historical market data; access option
  chains with Greeks; check fund limits or margin; build any trading
  automation for Indian markets; resolve NSE/BSE instrument IDs;
  stream live WebSocket market feeds or order updates. Also trigger
  for general questions about programmatic trading on Indian exchanges
  if Dhan is the user's broker.
compatibility: >
  Requires Ruby and the dhanhq gem.
  Order placement, modification, and cancellation require static IP
  whitelisting on Dhan. Data APIs (quotes, history, option chain,
  live feed) require an active Dhan Data Plan.
---

# DhanHQ — Indian Market Trading Skill (Ruby SDK)

Use this skill when an agent needs to write, review, or operate Ruby code using the `DhanHQ` gem.

## Safety Rules — Always Enforce

1. Confirm before placing live orders.
2. Show a readable order preview before execution.
3. Default to `LIMIT` orders unless the user explicitly wants `MARKET`.
4. Warn when notional exceeds `Rs. 50,000`.
5. For F&O, validate lot size before placement.
6. Never use `CNC` or `MTF` for F&O, commodity, or currency segments.
7. Never hardcode credentials in generated code.
8. Ask for confirmation before modifying or cancelling orders, or performing multi-leg live execution.

## Setup

Require the core library and configure using environment variables or a configuration block:

```ruby
require "dhan_hq"

# Configures from environment variables: DHAN_CLIENT_ID, DHAN_ACCESS_TOKEN
DhanHQ.configure_with_env
```

Or configure explicitly:

```ruby
DhanHQ.configure do |config|
  config.client_id = "YOUR_CLIENT_ID"
  config.access_token = "YOUR_ACCESS_TOKEN"
end
```

If generating scripts inside this repo, prefer using the helper script:

```ruby
require_relative "scripts/dhan_helpers"
get_client
```

## Current SDK Constants

Use constants from the `DhanHQ::Constants` module for segments, order types, validity, product types, and transactions:

| Category | Constant | Value |
|----------|----------|-------|
| Exchange Segment | `DhanHQ::Constants::ExchangeSegment::NSE_EQ` (or `DhanHQ::Constants::NSE`) | `"NSE_EQ"` |
| | `DhanHQ::Constants::ExchangeSegment::BSE_EQ` (or `DhanHQ::Constants::BSE`) | `"BSE_EQ"` |
| | `DhanHQ::Constants::ExchangeSegment::NSE_FNO` (or `DhanHQ::Constants::NSE_FNO` / `DhanHQ::Constants::FNO`) | `"NSE_FNO"` |
| | `DhanHQ::Constants::ExchangeSegment::BSE_FNO` (or `DhanHQ::Constants::BSE_FNO`) | `"BSE_FNO"` |
| | `DhanHQ::Constants::ExchangeSegment::MCX_COMM` (or `DhanHQ::Constants::MCX`) | `"MCX_COMM"` |
| | `DhanHQ::Constants::ExchangeSegment::IDX_I` (or `DhanHQ::Constants::INDEX`) | `"IDX_I"` |
| Transaction Type | `DhanHQ::Constants::TransactionType::BUY` (or `DhanHQ::Constants::BUY`) | `"BUY"` |
| | `DhanHQ::Constants::TransactionType::SELL` (or `DhanHQ::Constants::SELL`) | `"SELL"` |
| Order Type | `DhanHQ::Constants::OrderType::LIMIT` (or `DhanHQ::Constants::LIMIT`) | `"LIMIT"` |
| | `DhanHQ::Constants::OrderType::MARKET` (or `DhanHQ::Constants::MARKET`) | `"MARKET"` |
| | `DhanHQ::Constants::OrderType::STOP_LOSS` (or `DhanHQ::Constants::SL`) | `"STOP_LOSS"` |
| | `DhanHQ::Constants::OrderType::STOP_LOSS_MARKET` (or `DhanHQ::Constants::SLM`) | `"STOP_LOSS_MARKET"` |
| Product Type | `DhanHQ::Constants::ProductType::CNC` (or `DhanHQ::Constants::CNC`) | `"CNC"` |
| | `DhanHQ::Constants::ProductType::INTRADAY` (or `DhanHQ::Constants::INTRA`) | `"INTRADAY"` |
| | `DhanHQ::Constants::ProductType::MARGIN` (or `DhanHQ::Constants::MARGIN`) | `"MARGIN"` |
| | `DhanHQ::Constants::ProductType::MTF` (or `DhanHQ::Constants::MTF`) | `"MTF"` |
| Validity | `DhanHQ::Constants::Validity::DAY` (or `DhanHQ::Constants::DAY`) | `"DAY"` |
| | `DhanHQ::Constants::Validity::IOC` (or `DhanHQ::Constants::IOC`) | `"IOC"` |

## Preferred SDK Methods (ActiveRecord-Style Models)

| Task | Method |
|------|--------|
| Place order | `DhanHQ::Models::Order.place(params)` |
| List all orders | `DhanHQ::Models::Order.all` |
| Order by ID | `DhanHQ::Models::Order.find(order_id)` |
| Order by correlation ID | `DhanHQ::Models::Order.find_by_correlation(correlation_id)` |
| Today's trades | `DhanHQ::Models::Trade.today` |
| Historical trades | `DhanHQ::Models::Trade.history(from_date:, to_date:, page:)` |
| Holdings | `DhanHQ::Models::Holding.all` |
| Positions | `DhanHQ::Models::Position.all` |
| Fund limits | `DhanHQ::Models::Funds.fetch` |
| Margin calculator | `DhanHQ::Models::Margin.calculate(params)` |
| Multi-instrument margin | `DhanHQ::Models::Margin.calculate_multi(params)` |
| Daily charts | `DhanHQ::Models::HistoricalData.daily(params)` |
| Intraday charts | `DhanHQ::Models::HistoricalData.intraday(params)` |
| Option chain | `DhanHQ::Models::OptionChain.fetch(params)` |
| Expiry list | `DhanHQ::Models::OptionChain.fetch_expiry_list(params)` |
| Search instruments | `DhanHQ::Models::Instrument.search(query, options)` |
| Find specific instrument | `DhanHQ::Models::Instrument.find(exchange_segment, symbol, options)` |
| Find instrument anywhere | `DhanHQ::Models::Instrument.find_anywhere(symbol, options)` |
| Super orders | `DhanHQ::Models::SuperOrder.create(params)` |
| Forever orders | `DhanHQ::Models::ForeverOrder.create(params)` |
| Live market feed | `DhanHQ::WS.connect(mode: :ticker) { |tick| ... }` |
| Live order updates | `DhanHQ::WS::Orders.connect { |update| ... }` |
| Live market depth | `DhanHQ::WS::MarketDepth.connect(symbols: [{...}]) { |depth| ... }` |

## High-Value Gotchas

- **Return values are model instances:** Most class methods return `DhanHQ::Models` objects rather than raw HTTP hashes.
- **Instrument search is segment-specific:** `DhanHQ::Models::Instrument.by_segment(exchange_segment)` downloads the CSV for a single segment, which is more token-efficient than downloading the entire master CSV.
- **Spelling fixes in models:** Typos from the Dhan API are normalized in model attributes (e.g. `availabelBalance` is normalized to `available_balance` or `availabel_balance`).
- **Timestamps:** Timestamps returned by `HistoricalData` are automatically normalized into Ruby `Time` objects.
- **WebSocket connection management:** Use sequential connections or single connection pools to avoid 429 rate limiting. Dhan allows up to 5 concurrent WebSocket connections.

## Core Patterns

### 1. Check account access before data calls

```ruby
funds = DhanHQ::Models::Funds.fetch
puts "Available Balance: Rs. #{funds.availabel_balance}"
```

### 2. Fetch historical data

```ruby
candles = DhanHQ::Models::HistoricalData.daily(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2024-01-01",
  to_date: "2024-12-31"
)

candles.each do |candle|
  puts "Date: #{candle[:timestamp].to_date}, Close: #{candle[:close]}"
end
```

### 3. Option-chain data

```ruby
chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 13,
  underlying_seg: "IDX_I",
  expiry: "2025-03-27"
)

puts "Underlying spot: #{chain[:last_price]}"
chain[:strikes].each do |strike_data|
  puts "Strike: #{strike_data[:strike]}, Call LTP: #{strike_data[:call][:last_price]}"
end
```

### 4. Margin check before live order placement

```ruby
margin = DhanHQ::Models::Margin.calculate(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 10,
  product_type: "CNC",
  price: 2450.0
)

puts "Sufficient balance? #{margin.available_balance >= margin.total_margin}"
```

### 5. Live market feed

```ruby
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  puts "Market Tick: #{tick[:security_id]} = #{tick[:ltp]}"
end

market_client.subscribe_one(segment: "NSE_EQ", security_id: "2885")
sleep(10)
market_client.stop
```

## Reference Files

Refer to the documents in the references directory for focused workflows:

| Need | File |
|------|------|
| Orders, super orders, forever orders | [references/orders.md](references/orders.md) |
| Holdings, positions, eDIS | [references/portfolio.md](references/portfolio.md) |
| Daily/minute history, quotes, expired options | [references/market-data.md](references/market-data.md) |
| Option-chain usage | [references/option-chain.md](references/option-chain.md) |
| Fund limits and margin checks | [references/funds.md](references/funds.md) |
| Live feeds and depth | [references/live-feed.md](references/live-feed.md) |
| Error handling | [references/error-codes.md](references/error-codes.md) |
| Instrument resolution | [references/instruments.md](references/instruments.md) |
| Multi-step execution patterns | [references/common-workflows.md](references/common-workflows.md) |
| Options analytics | [references/options-analysis-patterns.md](references/options-analysis-patterns.md) |
| Backtesting patterns | [references/backtesting-with-dhan.md](references/backtesting-with-dhan.md) |
| Extranal data sources (RSI, PE ratios, screener) | [references/scanx-data.md](references/scanx-data.md) |
