# Orders — Complete Reference (Ruby SDK)

Critical API rules:
- Order placement, modification, cancellation, super orders, and forever orders require static IP whitelisting.
- Dhan's current order docs say API market orders are converted to limit orders with MPP.
- **`ENV["LIVE_TRADING"]="true"` is required for `place`/`create`/`modify`/`cancel` to actually submit anything** — the gem raises `DhanHQ::LiveTradingDisabledError` otherwise, as a safety gate against accidental order placement from a dev machine.
- **`correlation_id` must be 25 characters or fewer.** Dhan's real API rejects the entire order with a generic `DH-905` error if exceeded — it doesn't say which field was wrong.

## Regular Orders

### Place Order

In the Ruby SDK, prefer using the model class `DhanHQ::Models::Order.place(params)`:

```ruby
order = DhanHQ::Models::Order.place(
  security_id: "2885",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: 10,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  product_type: DhanHQ::Constants::ProductType::CNC,
  price: 2450.0,
  validity: DhanHQ::Constants::Validity::DAY,
  correlation_id: "rebalance_001"
)

if order
  puts "Placed Order ID: #{order.order_id}, Status: #{order.order_status}"
end
```

Alternatively, you can use the ActiveRecord-style `new` and `save` flow:

```ruby
order = DhanHQ::Models::Order.new(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 10,
  order_type: "LIMIT",
  product_type: "CNC",
  price: 2450.0,
  validity: "DAY"
)
order.save # Places the order via API
```

### Slice Order

If placing a large quantity that exceeds exchange freeze limits, the SDK handles slicing automatically when using the slice API:

```ruby
order.slice_order(
  slice_quantity: 1000
)
```

### Modify Order

Modify a pending order directly on the model instance:

```ruby
order = DhanHQ::Models::Order.find("112111182198")
if order.pending?
  order.modify(
    price: 2455.0,
    quantity: 10,
    validity: "DAY"
  )
end
```

The modify request expects the full placed quantity, not the pending quantity.

### Cancel Order

Cancel a pending order directly on the model instance:

```ruby
order = DhanHQ::Models::Order.find("112111182198")
order.cancel # Returns true on success
```

### Order Retrieval

```ruby
# Fetch all orders for today
orders = DhanHQ::Models::Order.all

# Find order by ID
order = DhanHQ::Models::Order.find("112111182198")

# Find order by correlation ID
order = DhanHQ::Models::Order.find_by_correlation("rebalance_001")

# Fetch today's trades
trades = DhanHQ::Models::Trade.today

# Find trades by order ID
trade = DhanHQ::Models::Trade.find_by_order_id("112111182198")

# Fetch trade history
history = DhanHQ::Models::Trade.history(
  from_date: "2025-01-01",
  to_date: "2025-01-31",
  page: 0
)
```

---

## Super Orders (Bracket/Cover Orders)

### Place Super Order

Use the `DhanHQ::Models::SuperOrder.create` method:

```ruby
super_order = DhanHQ::Models::SuperOrder.create(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 1,
  order_type: "LIMIT",
  product_type: "INTRADAY",
  price: 2450.0,
  target_price: 2500.0,
  stop_loss_price: 2420.0,
  trailing_jump: 10.0
)

puts "Placed Super Order ID: #{super_order.order_id}"
```

### Modify Super Order

```ruby
super_order.modify(
  leg_name: "ENTRY_LEG",
  price: 2455.0,
  quantity: 1,
  target_price: 2510.0,
  stop_loss_price: 2425.0,
  trailing_jump: 10.0
)
```

- `ENTRY_LEG` can modify the whole structure while the entry order is `PENDING` or `PART_TRADED`.
- After entry is `TRADED`, only price and trailing jump of `TARGET_LEG` and `STOP_LOSS_LEG` can be modified.

### Cancel Super Order

```ruby
super_order.cancel("ENTRY_LEG") # Cancels all legs
```

---

## Forever Orders (GTT Orders)

### Place Forever Order

Use the `DhanHQ::Models::ForeverOrder.create` method:

```ruby
# Single Trigger
gtt_order = DhanHQ::Models::ForeverOrder.create(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  product_type: "CNC",
  order_type: "LIMIT",
  quantity: 5,
  price: 2300.0,
  trigger_price: 2305.0,
  order_flag: "SINGLE",
  validity: "DAY"
)

# OCO (One Cancels Other) target + stop loss
oco_order = DhanHQ::Models::ForeverOrder.create(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "SELL",
  product_type: "CNC",
  order_type: "LIMIT",
  quantity: 5,
  price: 2700.00,        # Target price (price of first leg)
  trigger_price: 2695.00, # Target trigger price (trigger of first leg)
  price1: 2200.00,       # Stop loss price (price of second leg)
  trigger_price1: 2205.00, # Stop loss trigger price (trigger of second leg)
  quantity1: 5,          # Stop loss quantity (quantity of second leg)
  order_flag: "OCO",
  validity: "DAY"
)
```

### Cancel Forever Order

```ruby
gtt_order.cancel # Returns true on success
```
