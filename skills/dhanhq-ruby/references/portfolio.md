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

For selling delivery holdings, authorization is handled via `DhanHQ::Models::Edis`:

### Step 1: Generate TPIN
```ruby
DhanHQ::Models::Edis.generate_tpin
```

Triggers a TPIN to the user's registered mobile/email. Returns `{status: "accepted"}` — the API responds `202` for this async operation.

### Step 2: Generate and Render the Authorization Form
```ruby
form = DhanHQ::Models::Edis.generate_form(
  isin: "INE002A01018",
  qty: 5,
  exchange: "NSE",
  segment: "EQ"
)
# form[:edisFormHtml] is a browser-postable HTML form; render or POST it so the
# user can complete authorization on Dhan's eDIS page.
```

### Step 3: Inquire eDIS Approval
```ruby
status = DhanHQ::Models::Edis.inquire(isin: "INE002A01018") # or isin: "ALL"
puts "Approved Qty: #{status[:aprvdQty]}, Status: #{status[:status]}"
```

`inquire` returns the raw API response (a `HashWithIndifferentAccess`), not a model instance — key names match the API's camelCase (`aprvdQty`, `totalQty`), not the snake_case used elsewhere in this gem.
