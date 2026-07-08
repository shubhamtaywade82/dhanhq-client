# Portfolio And Positions — Complete Reference (Ruby SDK)

## Holdings

Use `DhanHQ::Models::Holding.all`:

```ruby
holdings = DhanHQ::Models::Holding.all

holdings.each do |holding|
  puts "#{holding.trading_symbol} available=#{holding.available_qty}"
end
```

Useful holding fields:
- `exchange`
- `trading_symbol`
- `security_id`
- `isin`
- `total_qty`
- `dp_qty`
- `t1_qty`
- `available_qty`
- `collateral_qty`
- `avg_cost_price`

---

## Positions

Use `DhanHQ::Models::Position.all`:

```ruby
positions = DhanHQ::Models::Position.all
open_positions = positions.select { |p| p.net_qty.to_i != 0 }
```

Useful position fields:
- `trading_symbol`
- `security_id`
- `position_type` # "LONG" or "SHORT"
- `exchange_segment`
- `product_type`
- `buy_avg`
- `buy_qty`
- `sell_avg`
- `sell_qty`
- `net_qty`
- `realized_profit`
- `unrealized_profit`

---

## Convert Position

Convert an open position (e.g. from Intraday to CNC/Carry Forward):

```ruby
# In the Ruby SDK, call convert directly on a Position model instance
position = DhanHQ::Models::Position.all.first
position.convert(
  from_product_type: "INTRADAY",
  to_product_type: "CNC",
  position_type: "LONG",
  convert_qty: 1
)
```

---

## eDIS Authorization

For selling delivery holdings, authorization is handled via `DhanHQ::Models::EDIS`:

### Step 1: Generate TPIN
```ruby
DhanHQ::Models::EDIS.generate_tpin
```

### Step 2: Open Browser Authorization
```ruby
DhanHQ::Models::EDIS.open_browser_for_tpin(
  isin: "INE002A01018",
  qty: 5,
  exchange: "NSE"
)
```

### Step 3: Inquiry eDIS Approval
```ruby
inquiry = DhanHQ::Models::EDIS.inquiry(isin: "INE002A01018")
puts "Approved Qty: #{inquiry.aprvd_qty}, Status: #{inquiry.status}"
```
