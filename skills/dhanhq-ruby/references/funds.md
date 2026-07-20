# Funds & Margin — Complete Reference (Ruby SDK)

The Ruby SDK exposes first-class models `DhanHQ::Models::Funds` and `DhanHQ::Models::Margin` for funds retrieval and pre-flight margin checks (both single-order and multi-leg).

## Fund Limits

Use `DhanHQ::Models::Funds.fetch`:

```ruby
funds = DhanHQ::Models::Funds.fetch

puts "Available Balance: Rs. #{funds.availabel_balance || funds.available_balance}"
puts "Utilized:          Rs. #{funds.utilized_amount}"
puts "Collateral:        Rs. #{funds.collateral_amount}"
puts "Withdrawable:      Rs. #{funds.withdrawable_balance}"
```

Normalized model attributes:
- `dhan_client_id`
- `availabel_balance` (or alias `available_balance`)
- `sod_limit`
- `collateral_amount`
- `receiveable_amount`
- `utilized_amount`
- `blocked_payout_amount`
- `withdrawable_balance`

---

## Margin Calculator — Single Order

Use `DhanHQ::Models::Margin.calculate(params)`:

```ruby
margin = DhanHQ::Models::Margin.calculate(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 10,
  product_type: "CNC",
  price: 2450.0
)

puts "Total Margin:       Rs. #{margin.total_margin}"
puts "Available Balance:  Rs. #{margin.available_balance}"
puts "Brokerage Charges:  Rs. #{margin.brokerage}"
puts "Leverage Offered:   #{margin.leverage}x"
```

---

## Multi-Order Margin

Unlike the Python SDK, the Ruby SDK has first-class support for multi-leg portfolio margin calculation via `DhanHQ::Models::Margin.calculate_multi(params)`:

```ruby
margin = DhanHQ::Models::Margin.calculate_multi(
  include_position: true,
  include_orders: true,
  scripts: [
    { exchange_segment: "NSE_EQ", transaction_type: "BUY", quantity: 100, product_type: "CNC", security_id: "1333", price: 1428.0 },
    { exchange_segment: "NSE_EQ", transaction_type: "SELL", quantity: 50, product_type: "INTRADAY", security_id: "11536", price: 3000.0 }
  ]
)

puts "Portfolio Total Margin Required: Rs. #{margin.total_margin}"
```
