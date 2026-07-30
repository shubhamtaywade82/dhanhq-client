---
title: Dhan Orders API — Ruby SDK & Client
description: Place, modify, cancel, and query orders using the DhanHQ Ruby gem. Supports equity, F&O, currency, and commodity segments for the Dhan API.
---

# Orders API

Place, modify, cancel, and query orders across NSE, BSE, NSE F&O, currency, and MCX segments.

## Place Order

```ruby
order = DhanHQ::Models::Order.create(
  dhan_client_id:    ENV["DHAN_CLIENT_ID"],
  transaction_type:  "BUY",
  exchange_segment:  "NSE_FNO",
  product_type:      "INTRADAY",
  order_type:        "MARKET",
  validity:          "DAY",
  security_id:       "12345",
  quantity:          15,
  correlation_id:    "strategy-entry-001"
)
```

### Correlation ID

Every order should include a `correlation_id` for idempotency and recovery.

## Modify Order

```ruby
DhanHQ::Models::Order.modify(
  order_id:   "12345",
  order_type: "LIMIT",
  price:      150.50,
  quantity:   20,
  validity:   "DAY"
)
```

## Cancel Order

```ruby
DhanHQ::Models::Order.cancel(order_id: "12345")
```

## Get Order

```ruby
order = DhanHQ::Models::Order.find("12345")
```

## Order History

```ruby
history = DhanHQ::Models::Order.history(order_id: "12345")
```

## All Orders

```ruby
orders = DhanHQ::Models::Order.all
```
