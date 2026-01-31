# PR: Dynamic access token resolution, auto-expiry detection, retry-on-401

## Summary

Adds production-grade auth handling to `dhanhq-client`:

1. **Dynamic access token resolution** — Token can come from a callable (`access_token_provider`) at request time.
2. **Auto-expiry detection** — API error code 807 (token expired) raises `DhanHQ::TokenExpiredError`.
3. **Retry-on-401 with token re-fetch** — On 401/token-expired, if `access_token_provider` is set, the client retries once; the next request calls the provider again for a fresh token.
4. **Optional `on_token_expired` hook** — Invoked before retry when auth failure triggers a retry (e.g. for logging or refreshing token in your store).

## Changes

- **Configuration**: `access_token_provider`, `on_token_expired`, `resolved_access_token`.
- **Errors**: `DhanHQ::AuthenticationError` (local token resolution failure), `DhanHQ::TokenExpiredError` (API 807).
- **Client**: Retry-on-401 for `InvalidAuthenticationError`, `InvalidTokenError`, `TokenExpiredError`, `AuthenticationFailedError` when provider is set (single retry).
- **REST + WebSocket**: All token usage goes through `config.resolved_access_token` (no memoization).

## Backward compatibility

- **Non-breaking**. Existing `config.access_token = "static-token"` still works. `access_token_provider` is optional. Safe as a **minor** version bump (2.2.0).

## Testing

- `spec/dhan_hq/configuration_spec.rb` — `#resolved_access_token` (provider, fallback, nil/empty).
- `spec/dhan_hq/client_spec.rb` — WebMock: 401, 403, 807, retry-on-401 success, retry then raise, `on_token_expired` hook.
- `spec/dhan_hq/helpers/response_helper_spec.rb` — 807 → TokenExpiredError.

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) — section **## [2.2.0] - 2026-01-31**.

## README & docs

- **README.md**: New subsection “Dynamic access token (optional)” under Configuration (access_token_provider, on_token_expired, retry-on-401, AuthenticationError / TokenExpiredError).
- **GUIDE.md**: Short “Dynamic access token” note and link to docs/AUTHENTICATION.md.
- **docs/AUTHENTICATION.md**: New doc for static vs dynamic token, retry-on-401, and auth-related errors.
- **docs/TESTING_GUIDE.md**: Optional access_token_provider / on_token_expired in config examples; verify “Token provider” in console.
- **docs/rails_integration.md**: New “Dynamic access token (optional)” with Rails initializer example.
- **docs/websocket_integration.md**, **docs/live_order_updates.md**: One-line pointer to docs/AUTHENTICATION.md for dynamic token.

## Checklist

- [x] All specs pass
- [x] No breaking changes
- [x] CHANGELOG updated
- [x] Version bumped to 2.2.0
- [x] README and docs updated
