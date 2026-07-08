# ScanX — Fundamental and Technical Data

Use ScanX when Dhan APIs do not cover the needed data. Dhan provides execution, quotes, OHLC, option chain, and portfolio. ScanX provides fundamentals, technical indicators, shareholding, and screeners.

## Capability Gap

| Data needed | Use |
|------------|-----|
| PE ratio, EPS, Book Value, PB Ratio | ScanX |
| Revenue, Net Profit, EBITDA | ScanX |
| Debt-to-equity, Return on Equity | ScanX |
| RSI(14), MACD(12,26), ADX(14), ATR(14) | ScanX |
| Promoter %, FII %, DII %, Public % | ScanX |
| Quarterly results history (2015–present) | ScanX |
| Balance Sheet, Cash Flows | ScanX |
| Stock screeners (fundamental/technical) | ScanX |
| Live quotes, OHLC, option chain | Dhan |
| Order execution, portfolio | Dhan |

---

## Company Page URL Pattern

`https://scanx.trade/company/{slug}`

Slug rules:
- Lowercase the full registered company name.
- Replace spaces with hyphens.
- Include "ltd" if part of the official name.

---

## Combined Workflow: Analyze on ScanX → Execute on Dhan

```ruby
# Step 1: fetch ScanX page for fundamentals/technicals
# -> https://scanx.trade/company/reliance-industries-ltd
# -> Extract metrics: PE, RSI, etc.

# Step 2: resolve security_id from Dhan security master
require_relative "../scripts/dhan_helpers"
get_client

row = resolve_symbol("RELIANCE", "NSE_EQ")
security_id = row["security_id"]

# Step 3: Get live quotes from Dhan
quote_resp = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [security_id.to_i])
ltp = quote_resp[:data]["NSE_EQ"][security_id.to_s][:last_price].to_f

# Step 4: Place order via Dhan
order = DhanHQ::Models::Order.place(
  security_id: security_id,
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 1,
  order_type: "LIMIT",
  product_type: "CNC",
  price: ltp,
  validity: "DAY"
)
```
