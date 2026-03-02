# API Validation Gap Analysis: DhanHQ vs Gem

Comprehensive audit of field-level constraints between official Dhan API documentation and the `dhanhq-client` gem's `Dry::Validation` contracts.

## 1. Core Enumerations & Constants

| Const Module | Missing in Gem | Incorrect in Gem | Status |
| :--- | :--- | :--- | :--- |
| `ExchangeSegment` | `NSE_COMM` | `NSE_CURRENCY`, `BSE_CURRENCY` (Not in spec) | **Mismatch** |
| `AmoTime` | None | None | Match |
| `ProductType` | None | None | Match |

> [!NOTE]
> `NSE_COMM` is explicitly listed in `OrderRequest` and `KnowYourMarginReq` schemas but missing from `DhanHQ::Constants::ExchangeSegment`.

---

## 2. Contract Gap Analysis

### Order Placement/Modification (`OrderContract`, `PlaceOrderContract`)

| Field | API Constraint | Gem Contract | Issue |
| :--- | :--- | :--- | :--- |
| `correlationId` | Max 30 chars, Alphanumeric | Max 25 chars | **Restrictive** |
| `disclosed_quantity` | Must be ≥ 30% of quantity | Failure if > 30% | **Reversed Logic** |
| `productType` | Includes `MTF` | Included | Match |
| `price` | Required for `LIMIT`, `STOP_LOSS` | Optional in params | **Missing Rule** |
| `boProfitValue` | Required for `BO` orders | Included | Match |

### Margin Calculator (`MarginCalculatorContract`)

| Field | API Constraint | Gem Contract | Issue |
| :--- | :--- | :--- | :--- |
| `exchangeSegment` | All segments (NSE, BSE, MCX) | `[NSE_EQ, NSE_FNO, BSE_EQ]` | **Incomplete** |
| `price` | Optional | Required | **Restrictive** |
| `triggerPrice` | Optional | Optional | Match |

### Position Conversion (`PositionConversionContract`)

| Field | API Constraint | Gem Contract | Issue |
| :--- | :--- | :--- | :--- |
| `exchangeSegment` | Exclude `IDX_I`, `NSE_COMM` | Uses all segments | **Gap** |
| `fromProductType` | `CNC`, `INTRADAY`, `MARGIN`, etc. | Uses all types | Match |

### Conditional Triggers (`AlertOrderContract`)

| Field | API Constraint | Gem Contract | Issue |
| :--- | :--- | :--- | :--- |
| Structure | Nested (`condition`, `orders[]`) | Flat | **Critical Mismatch** |
| `condition` | Object with logic fields | String | **Missing Logic** |

### Historical/Expired Data (`HistoricalDataContract`, `ExpiredOptionsDataContract`)

| Field | API Constraint | Gem Contract | Issue |
| :--- | :--- | :--- | :--- |
| `interval` | `1, 5, 15, 25, 60` | Match | Match |
| `oi` (Open Interest) | Boolean (Derivatives only) | Not explicitly validated | **Gap** |

---

## 3. Missing Contracts

The following API request models are currently missing validation contracts in the gem:

1. `PnlBasedExitRequest` (For P&L based exit)
2. `EdisFormRequest` (Electronic delivery instruction)
3. `UserIPRequest` (Static IP configuration)
4. `MultiScripMarginCalcRequest` (Bulk margin calculation)

---

## 4. Proposed Production-Ready Patches

### Patch 1: Reverse Disclosed Quantity Logic
```diff
 rule(:disclosed_quantity) do
-  key.failure("cannot exceed 30% of total quantity") if value && value > (values[:quantity] * 0.3)
+  key.failure("must be at least 30% of total quantity") if value && value < (values[:quantity] * 0.3)
 end
```

### Patch 2: Conditional Price Requirement
```ruby
rule(:price, :order_type) do
  if %w[LIMIT STOP_LOSS].include?(values[:order_type]) && !value
    key.failure("is required for LIMIT and STOP_LOSS orders")
  end
end
```

### Patch 3: Alert Nested Structure
```ruby
params do
  required(:dhanClientId).filled(:string)
  required(:condition).hash do
    required(:securityId).filled(:string, max_size?: 20)
    required(:comparisonType).filled(:string)
    # ... other condition fields
  end
  required(:orders).array(:hash) do
    # ... order fields
  end
end
```
