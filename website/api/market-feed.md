---
title: Dhan Market Feed API — Ruby SDK & Client
description: Fetch LTP, quote, and OHLC data using the DhanHQ Ruby gem REST endpoints for the Dhan API.
---

# Market Feed (REST)

Snapshot market data for up to 1,000 instruments at once.

## LTP

```ruby
data = DhanHQ::Models::MarketFeed.ltp(
  NSE_EQ: ["1333", "2885"],
  IDX_I:  ["13", "25"]
)
```

## Quote

```ruby
quote = DhanHQ::Models::MarketFeed.quote(
  NSE_EQ: ["1333"]
)
```

For real-time streaming, use the [WebSocket market feed](/websocket/market-feed).
