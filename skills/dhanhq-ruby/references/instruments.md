# Instruments — Complete Reference (Ruby SDK)

Use the security master as the primary source for `security_id`, lot size, expiry, strike, tick size, and display symbol.

## Preferred SDK Entry Point

In the Ruby SDK, search and load instruments segment-wise using:

```ruby
# Retrieve compact list for a single segment (returns Array of Instrument objects)
instruments = DhanHQ::Models::Instrument.by_segment("NSE_EQ")
```

Official instrument sources (managed by the SDK internally):
- Compact CSV: `https://images.dhan.co/api-data/api-scrip-master.csv`
- Detailed CSV: `https://images.dhan.co/api-data/api-scrip-master-detailed.csv`

---

## Key Columns (Instrument Attributes)

| Attribute | Meaning |
|-----------|---------|
| `security_id` | Security ID (String) |
| `exchange` | Exchange ID (`NSE`, `BSE`, `MCX`) |
| `instrument` | Instrument Type (`EQUITY`, `OPTIDX`, `OPTSTK`, etc.) |
| `symbol_name` | Exchange trading symbol |
| `display_name` | Dhan custom symbol |
| `lot_size` | Lot size (Integer) |
| `tick_size` | Tick size (Float) |
| `expiry_date` | Expiry date (String) |
| `strike_price` | Strike price (Float) |
| `option_type` | Option Type (`CALL` or `PUT`) |

---

## Recommended Resolution Flow

Use the SDK's built-in helper methods on the `Instrument` class:

```ruby
# Find specific instrument in a segment by symbol name (exact match)
inst = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")

# Find by security ID instead of symbol name — use this, not `.find`, when you
# already have a security_id (e.g. from an order, position, or option chain leg)
inst = DhanHQ::Models::Instrument.find_by_security_id("NSE_EQ", "2885")

# Search across multiple segments (finds any match)
inst = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")

# Fuzzy search across multiple segments
results = DhanHQ::Models::Instrument.search("RELIANCE")
```

`.find`'s second argument is always a **symbol name**, never a security ID — passing a security ID there silently returns `nil` (it searches symbol/underlying-symbol text, doesn't match on ID). Use `.find_by_security_id` when resolving by ID.

Or leverage the helper layer in `scripts/dhan_helpers.rb`:

```ruby
require_relative "../scripts/dhan_helpers"

cash = resolve_symbol("RELIANCE", "NSE_EQ")
contract = resolve_derivative("NIFTY", strike: 24000, option_type: "CE", expiry: "2025-03-27")
lot_size = get_lot_size(underlying: "NIFTY")
```

---

## Quick-Reference Fallback IDs

### Index Underlyings

| Underlying | security_id | Underlying Segment |
|------------|-------------|-------------------|
| NIFTY 50 | `13` | `IDX_I` |
| BANK NIFTY | `25` | `IDX_I` |
| FINNIFTY | `27` | `IDX_I` |
| MIDCPNIFTY | `442` | `IDX_I` |
| SENSEX | `51` | `IDX_I` |

### Common NSE Equities

| Symbol | security_id |
|--------|-------------|
| RELIANCE | `2885` |
| HDFCBANK | `1333` |
| TCS | `11536` |
| INFY | `1594` |
| ICICIBANK | `4963` |
| SBIN | `3045` |
