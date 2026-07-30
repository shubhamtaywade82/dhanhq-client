---
title: Dhan Portfolio API — Ruby SDK & Client
description: Query holdings, positions, funds, and trade book using the DhanHQ Ruby gem for portfolio management with the Dhan API.
---

# Portfolio & Funds

## Holdings

```ruby
holdings = DhanHQ::Models::Holding.all
```

## Positions

```ruby
positions = DhanHQ::Models::Position.all
```

## Funds

```ruby
funds = DhanHQ::Models::Funds.fetch
puts "Available: #{funds.available_balance}"
puts "Withdrawable: #{funds.withdrawable_balance}"
```

## Trade Book

```ruby
# Today's trades
trades = DhanHQ::Models::Trade.today

# Historical trades with date range
history = DhanHQ::Models::Trade.history(
  from_date: "2026-07-01",
  to_date:   "2026-07-30"
)
```
