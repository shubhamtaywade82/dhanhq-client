# Common Workflows — Agent Playbooks (Ruby SDK)

## Portfolio Rebalance

Recommended sequence:
1. Fetch holdings and funds.
2. Compute target deltas.
3. Resolve symbols and quantities.
4. Preview proposed orders.
5. Confirm with the user.
6. Place live orders.

```ruby
holdings = DhanHQ::Models::Holding.all rescue []
funds = DhanHQ::Models::Funds.fetch rescue nil

if funds
  available_cash = funds.availabel_balance || funds.available_balance || 0.0
end
```

## Delivery Sell With eDIS

Use this flow for selling demat holdings:
1. Fetch holdings and identify ISIN.
2. Generate TPIN: `DhanHQ::Models::EDIS.generate_tpin`
3. Open authorization form: `DhanHQ::Models::EDIS.open_browser_for_tpin(isin: "...", qty: 5, exchange: "NSE")`
4. Check inquiry: `DhanHQ::Models::EDIS.inquiry(isin: "...")`
5. Place the sell order.

```ruby
# Generate TPIN
DhanHQ::Models::EDIS.generate_tpin

# Open authorization portal
DhanHQ::Models::EDIS.open_browser_for_tpin(isin: "INE002A01018", qty: 5, exchange: "NSE")

# Inquiry
status = DhanHQ::Models::EDIS.inquiry(isin: "INE002A01018")
```

## Single-Leg F&O Execution

Recommended sequence:
1. Resolve current contract from option chain or security master.
2. Resolve lot size.
3. Validate quantity.
4. Check margin.
5. Preview & Confirm.
6. Place live order.

```ruby
require_relative "../scripts/dhan_helpers"

chain_df, spot = fetch_chain_df(under_security_id: 13, expiry: "2025-03-27")
atm = find_atm_row(chain_df, spot)

margin = check_margin(
  security_id: atm["ce_security_id"],
  exchange_segment: "NSE_FNO",
  transaction_type: "BUY",
  quantity: 75,
  product_type: "INTRADAY",
  price: atm["ce_ltp"].to_f
)
```

## Daily P&L Summary

```ruby
require_relative "../scripts/dhan_helpers"

holdings = DhanHQ::Models::Holding.all
positions = DhanHQ::Models::Position.all
summary = format_pnl_report(holdings, positions)
```
