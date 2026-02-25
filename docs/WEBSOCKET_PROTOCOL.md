# WebSocket Protocol Reference

Low-level protocol details for the DhanHQ WebSocket market feed. For high-level usage, see the [WebSocket Integration Guide](WEBSOCKET_INTEGRATION.md).

---

## Subscription Modes

| Mode      | What you get                              | Best for                        |
| --------- | ----------------------------------------- | ------------------------------- |
| `:ticker` | LTP + LTT                                | Lightweight price monitoring    |
| `:quote`  | LTP + LTT + OHLCV + totals               | Most trading strategies         |
| `:full`   | Quote + OI + best-5 depth (bid/ask)       | Order book analysis, depth-based strategies |

---

## Request Codes

Per Dhan documentation:

| Action       | Ticker | Quote | Full |
| ------------ | ------ | ----- | ---- |
| Subscribe    | 15     | 17    | 21   |
| Unsubscribe  | 16     | 18    | 22   |
| Disconnect   | 12     | 12    | 12   |

---

## Packet Parsing

### Response Header (8 bytes)

| Field                | Size   | Encoding | Description                   |
| -------------------- | ------ | -------- | ----------------------------- |
| `feed_response_code` | 1 byte | u8, BE   | Identifies the packet type    |
| `message_length`     | 2 bytes| u16, BE  | Total message length in bytes |
| `exchange_segment`   | 1 byte | u8, BE   | Exchange segment identifier   |
| `security_id`        | 4 bytes| i32, LE  | Security identifier           |

### Packet Types

| Code | Type          | Fields                                                        |
| ---- | ------------- | ------------------------------------------------------------- |
| 1    | Index         | Surfaced as raw/misc unless documented                       |
| 2    | Ticker        | `ltp`, `ltt`                                                 |
| 4    | Quote         | `ltp`, `ltt`, `atp`, `volume`, totals, `day_*`               |
| 5    | OI            | `open_interest`                                              |
| 6    | Prev Close    | `prev_close`, `oi_prev`                                      |
| 7    | Market Status | Raw/misc unless documented                                   |
| 8    | Full          | Quote fields + `open_interest` + 5× depth (bid/ask)         |
| 50   | Disconnect    | Reason code                                                  |

---

## Normalized Tick Schema

All ticks are delivered as a Ruby Hash with consistent keys:

```ruby
{
  kind: :quote,               # :ticker | :quote | :full | :oi | :prev_close | :misc
  segment: "NSE_FNO",         # string enum
  security_id: "12345",
  ltp: 101.5,
  ts:  1723791300,            # LTT epoch (sec) if present
  vol: 123456,                # quote/full only
  atp: 100.9,                 # quote/full only
  day_open: 100.1,
  day_high: 102.4,
  day_low: 99.5,
  day_close: nil,
  oi: 987654,                 # full or OI packet
  bid: 101.45,                # from depth (mode :full)
  ask: 101.55                 # from depth (mode :full)
}
```

---

## Connection Limits & Behavior

### Limits

- **100 instruments** per subscribe/unsubscribe frame (auto-chunked by the client)
- **5 WebSocket connections** per user (per Dhan)

### Backoff & 429 Cool-Off

- Exponential backoff with jitter on connection failure
- Handshake **429** triggers a **60-second cool-off** before retry
- The client handles this automatically — avoid manual rapid reconnect loops

### Reconnect & Resubscribe

- On reconnect, the client resends the **current subscription snapshot** (idempotent)
- No manual re-subscribe needed after automatic reconnection

### Graceful Shutdown

- `ws.disconnect!` — sends broker disconnect code 12, prevents reconnects
- `ws.stop` — hard stop (no broker message, just closes and halts loop)
- `DhanHQ::WS.disconnect_all_local!` — kills all registered WS clients
- An `at_exit` hook stops all registered clients to avoid leaked sockets

---

## Exchange Segment Enums

Use these string enums in WebSocket `subscribe_*` calls and REST parameters:

| Enum           | Exchange | Segment           |
| -------------- | -------- | ----------------- |
| `IDX_I`        | Index    | Index Value       |
| `NSE_EQ`       | NSE      | Equity Cash       |
| `NSE_FNO`      | NSE      | Futures & Options |
| `NSE_CURRENCY` | NSE      | Currency          |
| `BSE_EQ`       | BSE      | Equity Cash       |
| `BSE_FNO`      | BSE      | Futures & Options |
| `BSE_CURRENCY` | BSE      | Currency          |
| `MCX_COMM`     | MCX      | Commodity         |

---

## Tick Access Patterns

### Direct Handler

```ruby
ws.on(:tick) { |t| do_something_fast(t) }  # avoid heavy work here
```

### Shared TickCache (Recommended)

```ruby
# app/services/live/tick_cache.rb
class TickCache
  MAP = Concurrent::Map.new
  def self.put(t)  = MAP["#{t[:segment]}:#{t[:security_id]}"] = t
  def self.get(seg, sid) = MAP["#{seg}:#{sid}"]
  def self.ltp(seg, sid) = get(seg, sid)&.dig(:ltp)
end

ws.on(:tick) { |t| TickCache.put(t) }
ltp = TickCache.ltp("NSE_FNO", "12345")
```

### Filtered Callback

```ruby
def on_tick_for(ws, segment:, security_id:, &blk)
  key = "#{segment}:#{security_id}"
  ws.on(:tick) { |t| blk.call(t) if "#{t[:segment]}:#{t[:security_id]}" == key }
end
```
