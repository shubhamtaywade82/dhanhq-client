# Options Analysis Patterns (Ruby SDK)

Use the normalized helper output from `scripts/dhan_helpers.rb` for option chain analysis:

```ruby
require_relative "../scripts/dhan_helpers"

chain_rows, spot = fetch_chain_df(
  under_security_id: 13,
  expiry: "2025-03-27",
  under_exchange_segment: "IDX_I"
)

atm = find_atm_row(chain_rows, spot)
```

## Put-Call Ratio (PCR)

```ruby
total_ce_oi = chain_rows.sum { |r| r["ce_oi"].to_f }
total_pe_oi = chain_rows.sum { |r| r["pe_oi"].to_f }
pcr = total_ce_oi > 0 ? (total_pe_oi / total_ce_oi) : 0.0
puts "PCR: #{'%.2f' % pcr}"
```

## OI Support / Resistance

Find strikes with the highest open interest for resistance (CE) and support (PE):

```ruby
# Top 3 resistance walls (highest Call OI)
ce_walls = chain_rows.sort_by { |r| -(r["ce_oi"] || 0) }.first(3)

# Top 3 support walls (highest Put OI)
pe_walls = chain_rows.sort_by { |r| -(r["pe_oi"] || 0) }.first(3)
```

## IV Skew

```ruby
otm_puts = chain_rows.select { |r| r["strike"] < spot }.sort_by { |r| -r["strike"] }.first(3)
otm_calls = chain_rows.select { |r| r["strike"] > spot }.sort_by { |r| r["strike"] }.first(3)

put_iv_avg = otm_puts.sum { |r| r["pe_iv"].to_f } / otm_puts.size.to_f
call_iv_avg = otm_calls.sum { |r| r["ce_iv"].to_f } / otm_calls.size.to_f
skew = put_iv_avg - call_iv_avg
```

## Max Pain

Calculate the option strike price where option buyers would experience the maximum loss:

```ruby
def calculate_max_pain(chain_rows)
  strikes = chain_rows.map { |r| r["strike"] }
  pain = {}

  strikes.each do |test_price|
    total = 0.0
    chain_rows.each do |row|
      strike = row["strike"]
      ce_oi = row["ce_oi"].to_f
      pe_oi = row["pe_oi"].to_f
      
      total += [test_price - strike, 0.0].max * ce_oi
      total += [strike - test_price, 0.0].max * pe_oi
    end
    pain[test_price] = total
  end

  pain.min_by { |_strike, total_pain| total_pain }&.first
end

max_pain_strike = calculate_max_pain(chain_rows)
puts "Max Pain Strike: #{max_pain_strike}"
```
