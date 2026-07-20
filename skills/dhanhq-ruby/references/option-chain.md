# Option Chain — Complete Reference (Ruby SDK)

For analysis code, use the helper layer `fetch_chain_df` from `scripts/dhan_helpers.rb`.

## Expiry List

Use `DhanHQ::Models::OptionChain.fetch_expiry_list(params)`:

```ruby
expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
  underlying_scrip: 13,
  underlying_seg: "IDX_I"
)
```

## Option Chain

Use `DhanHQ::Models::OptionChain.fetch(params)`:

```ruby
chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 13,
  underlying_seg: "IDX_I",
  expiry: "2025-03-27"
)

# Underlying LTP
spot = chain[:last_price]

# Strikes sorted array
chain[:strikes].each do |strike_data|
  puts "Strike: #{strike_data[:strike]}"
  puts "Call LTP: #{strike_data[:call][:last_price]}"
  puts "Put Delta: #{strike_data[:put][:greeks][:delta]}"
end
```

### Rate Limits
- Calls are limited to **1 request every 3 seconds**. The SDK's internal rate limiter handles this.

---

## Normalized Helper Layer

```ruby
require_relative "../scripts/dhan_helpers"

chain_rows, spot = fetch_chain_df(
  under_security_id: 13,
  expiry: "2025-03-27",
  under_exchange_segment: "IDX_I"
)

atm = find_atm_row(chain_rows, spot)
puts "Spot: #{spot}, ATM Strike: #{atm['strike']}, Call LTP: #{atm['ce_ltp']}"
```

Normalized columns returned by `fetch_chain_df`:
- `strike`
- `ce_security_id`, `pe_security_id`
- `ce_ltp`, `pe_ltp`
- `ce_oi`, `pe_oi`
- `ce_oi_change`, `pe_oi_change`
- `ce_volume`, `pe_volume`
- `ce_iv`, `pe_iv`
- `ce_bid_price`, `pe_bid_price`
- `ce_ask_price`, `pe_ask_price`
- `ce_delta`, `pe_delta`
- `ce_gamma`, `pe_gamma`
- `ce_theta`, `pe_theta`
- `ce_vega`, `pe_vega`
