---
title: Dhan Instruments & Option Chain API — Ruby SDK
description: Search instruments, fetch scrip master data, and resolve option chains using the DhanHQ Ruby gem for the Dhan API.
---

# Instruments & Option Chain

## Search Instruments

```ruby
results = DhanHQ::Models::Instrument.search("RELIANCE")
```

## By Segment

```ruby
fno_instruments = DhanHQ::Models::Instrument.by_segment("NSE_FNO")
```

## Option Chain

```ruby
chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 13,
  underlying_seg:   "IDX_I",
  expiry:           "2026-08-04"
)
```

## Expiry List

```ruby
expiries = DhanHQ::Models::OptionChain.expiry_list(
  underlying_scrip: 13,
  underlying_seg:   "IDX_I"
)
```
