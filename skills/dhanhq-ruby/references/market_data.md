# Market data with agents

Use `DhanHQ::Models::Instrument.search` to resolve a query to Dhan security IDs, then call `DhanHQ::Models::MarketFeed.ltp`, `.ohlc`, or `.quote` with an exchange-segment keyed payload.
