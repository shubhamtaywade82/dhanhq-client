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
limits = DhanHQ::Models::FundLimit.current
```

## Trade Book

```ruby
trades = DhanHQ::Models::TradeBook.where(
  from_date: "2026-07-01",
  to_date:   "2026-07-30"
)
```
