# Troubleshooting

Common issues and solutions when working with the DhanHQ Ruby client.

---

## 429: Unexpected Response Code

**Symptom:** WebSocket connection fails with a 429 status.

**Cause:** Too many connections opened in quick succession, or exceeding the per-user WebSocket connection limit (5 per user).

**Solution:**
- The client automatically cools off for **60 seconds** and retries with exponential backoff.
- Prefer `ws.disconnect!` before reconnecting to cleanly release server-side resources.
- Call `DhanHQ::WS.disconnect_all_local!` to kill any straggler connections.
- Avoid rapid connect/disconnect loops — the client handles backoff internally.

```ruby
# Kill all local WebSocket connections
DhanHQ::WS.disconnect_all_local!

# Wait before reconnecting
sleep(2)

# Reconnect
client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick[:ltp] }
```

---

## No Ticks After Reconnect

**Symptom:** WebSocket reconnects successfully but no market data arrives.

**Cause:** Subscriptions were not restored after the connection dropped.

**Solution:**
- The client **automatically resends** the current subscription snapshot on reconnect — this should work transparently.
- If you're managing connections manually, ensure you re-subscribe after a clean start.
- Check that your instruments are valid and the market is open.

---

## Binary Parse Errors

**Symptom:** Errors in logs related to binary frame parsing.

**Cause:** Malformed or unexpected binary frames from the server.

**Solution:**
- The client safely drops malformed frames and keeps the event loop alive.
- Run with `DHAN_LOG_LEVEL=DEBUG` to inspect raw frames:

```bash
export DHAN_LOG_LEVEL=DEBUG
```

```ruby
DhanHQ.logger.level = Logger::DEBUG
```

---

## Authentication Errors

| Error Class                          | Meaning                                                    |
| ------------------------------------ | ---------------------------------------------------------- |
| `DhanHQ::AuthenticationError`        | Token could not be resolved (missing config, nil provider) |
| `DhanHQ::InvalidAuthenticationError` | API returned 401 or error code DH-901                      |
| `DhanHQ::TokenExpiredError`          | API returned error code 807 (token expired)                |
| `DhanHQ::InvalidTokenError`          | API returned error code 809 (invalid token)                |

**Solutions:**
- Verify `DHAN_CLIENT_ID` and `DHAN_ACCESS_TOKEN` are set correctly.
- If using `access_token_provider`, ensure it returns a non-nil string.
- For 401 retries: the client retries **once** with a fresh token when `access_token_provider` is configured.
- See [AUTHENTICATION.md](AUTHENTICATION.md) for detailed token lifecycle handling.

---

## Connection Timeouts

**Symptom:** REST API calls hang or fail with timeout errors.

**Solution:** Adjust timeout settings via environment variables:

```dotenv
DHAN_CONNECT_TIMEOUT=15   # default: 10 seconds
DHAN_READ_TIMEOUT=60      # default: 30 seconds
DHAN_WRITE_TIMEOUT=60     # default: 30 seconds
```

---

## Debug Logging

Enable full debug output to diagnose any issue:

```ruby
DhanHQ.logger.level = Logger::DEBUG
```

Or via environment:

```bash
export DHAN_LOG_LEVEL=DEBUG
```

This logs HTTP requests/responses, WebSocket frames, and internal state transitions.

---

## Getting Help

- [DhanHQ GitHub Issues](https://github.com/shubhamtaywade82/dhanhq-client/issues)
- [Dhan API Documentation](https://dhanhq.co/docs/v2/)
