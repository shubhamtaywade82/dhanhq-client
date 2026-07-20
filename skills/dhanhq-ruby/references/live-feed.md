# Live Feed — Complete Reference (Ruby SDK)

The Ruby SDK provides three distinct WebSocket interfaces under the `DhanHQ::WS` namespace to handle live data streaming.

## 1. Market Feed (`DhanHQ::WS.connect`)

Real-time market ticks, last traded prices, quotes, and market depth updates.

### Usage

```ruby
# Connect to market feed. Modes: :ticker, :quote, :full
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Tick: #{tick[:segment]}:#{tick[:security_id]} LTP=#{tick[:ltp]} at #{timestamp}"
end

# Subscribe to segments and security IDs
market_client.subscribe_one(segment: "NSE_EQ", security_id: "2885")
market_client.subscribe_one(segment: "NSE_EQ", security_id: "1333")

# Stop connection
sleep(15)
market_client.stop
```

### Modes
- `:ticker` - LTP (Last Traded Price) only.
- `:quote` - OHLC + Volume updates.
- `:full` - Full quote depth (5 levels) and Open Interest (OI) updates.

---

## 2. Order Updates (`DhanHQ::WS::Orders.connect`)

Streams real-time updates for placed, modified, executed, or rejected orders.

### Usage

```ruby
orders_client = DhanHQ::WS::Orders.connect do |update|
  puts "Order Update: #{update.order_no} status=#{update.status}"
  puts "  Symbol: #{update.symbol}, Traded: #{update.traded_qty}/#{update.quantity}"
end

# Register event callbacks
orders_client.on(:update) { |order| puts "📝 Order Modified: #{order.order_no}" }
orders_client.on(:execution) { |exec| puts "✅ Executed: #{exec[:new_traded_qty]} shares" }
orders_client.on(:order_rejected) { |order| puts "❌ Rejected: #{order.order_no}" }

sleep(15)
orders_client.stop
```

---

## 3. Market Depth (`DhanHQ::WS::MarketDepth.connect`)

Streams order book depth (bid/ask levels). Supports 20-level depth.

### Usage

```ruby
symbols = [
  { symbol: "RELIANCE", exchange_segment: "NSE_EQ", security_id: "2885" },
  { symbol: "TCS", exchange_segment: "NSE_EQ", security_id: "11536" }
]

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth|
  puts "Symbol: #{depth[:symbol]} Spread: #{depth[:spread]}"
  puts "  Best Bid: #{depth[:best_bid]} | Best Ask: #{depth[:best_ask]}"
end

sleep(15)
depth_client.stop
```

---

## Connection Limits & Cleanup

- Dhan allows up to **5 concurrent WebSocket connections** per client account.
- Always call `client.stop` or `DhanHQ::WS.disconnect_all_local!` to prevent socket leaks and rate-limit issues (`429 Too Many Requests`).
