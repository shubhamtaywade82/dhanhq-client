---
title: Dhan Super Orders API — Ruby SDK & Client
description: Place bracket orders and cover orders using the DhanHQ Ruby gem with multi-leg order support for the Dhan API.
---

# Super Orders

Place multi-leg order structures including bracket orders and cover orders.

## Bracket Order

```ruby
order = DhanHQ::Models::SuperOrder.create(
  dhan_client_id:   ENV["DHAN_CLIENT_ID"],
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  order_type:       "LIMIT",
  product_type:     "INTRADAY",
  security_id:      "1333",
  quantity:         100,
  price:            750,
  stop_loss_price:  740,
  target_price:     760,
  trailing_jump:    10
)
```

## Cover Order

```ruby
order = DhanHQ::Models::SuperOrder.create(
  dhan_client_id:   ENV["DHAN_CLIENT_ID"],
  exchange_segment: "NSE_FNO",
  transaction_type: "BUY",
  order_type:       "LIMIT",
  product_type:     "INTRADAY",
  security_id:      "58072",
  quantity:         50,
  price:            25000,
  stop_loss_price:  24900,
  target_price:     25200,
  trailing_jump:    10
)
```

See the [Super Orders guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/SUPER_ORDERS.md) for full documentation.
