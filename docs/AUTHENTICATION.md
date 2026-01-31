# Authentication & token handling

This document describes how the gem handles access tokens, including dynamic resolution, retry-on-401, and related errors.

## Static token (default)

Set `access_token` once; it is sent on every request:

```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token = ENV["ACCESS_TOKEN"]
end
```

## Dynamic access token

For production or OAuth-style flows, resolve the token at **request time** so it can rotate without restarting the app:

```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token_provider = lambda do
    record = YourTokenStore.active  # e.g. from DB or OAuth
    raise "Token expired or missing" unless record
    record.access_token
  end
  config.on_token_expired = ->(error) { YourTokenStore.refresh! }  # optional
end
```

- **`access_token_provider`**: Callable (Proc/lambda) that returns the access token string. Called on **every request** (no memoization). When set, the gem uses it instead of `access_token`.
- **`on_token_expired`**: Optional callable invoked when a 401/token-expired triggers a **single retry** (only when `access_token_provider` is set). Use for logging or refreshing your store; the retry then uses the token from the provider.

REST and WebSocket clients both use `config.resolved_access_token`, which calls the provider when set or falls back to `access_token`.

## Retry-on-401

When the API returns **401** or a token-expired error (e.g. error code **807**), and `access_token_provider` is set:

1. The client catches the auth error (`InvalidAuthenticationError`, `InvalidTokenError`, `TokenExpiredError`, or `AuthenticationFailedError`).
2. It calls `on_token_expired&.call(error)` if configured.
3. It retries the request **once**. The retry uses `build_headers` → `resolved_access_token` → provider again, so the next token is used.

If the provider is not set, or the retry also returns 401, the error is raised. There is no second retry for auth failures.

## Errors

| Error | When |
| ----- | ----- |
| **`DhanHQ::AuthenticationError`** | Token could not be resolved: missing config, or `access_token_provider` returned nil/empty. |
| **`DhanHQ::InvalidAuthenticationError`** | API returned 401 or error code DH-901 (invalid/expired token). |
| **`DhanHQ::TokenExpiredError`** | API returned error code **807** (token expired). |
| **`DhanHQ::InvalidTokenError`** | API returned error code 809 (invalid token). |
| **`DhanHQ::AuthenticationFailedError`** | API returned error code 808 (auth failed). |

Rescue `AuthenticationError` for local config/token resolution failures; rescue `InvalidAuthenticationError` / `TokenExpiredError` for API-reported auth failures.

## See also

- [README.md](../README.md) — Configuration and “Dynamic access token”
- [rails_integration.md](rails_integration.md) — Rails initializer with optional `access_token_provider`
- [CHANGELOG.md](../CHANGELOG.md) — 2.2.0 auth and token changes
