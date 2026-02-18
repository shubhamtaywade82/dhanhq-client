# Authentication & token handling

This document describes how the gem handles access tokens, dynamic resolution, retry-on-401, and how that fits with Dhan’s authentication methods.

## How you get the token (Dhan’s responsibility)

Dhan supports several ways to obtain an access token. **The gem does not implement these flows**; your app or the user obtains the token, and the gem uses it.

| User type | Method | Where it happens |
| --------- |--------|------------------|
| **Individual** | **Access token from Dhan Web** | User logs in at web.dhan.co → My Profile → Access DhanHQ APIs → Generate token (24h). You can refresh it with **RenewToken** (see below); the gem can call that for you. |
| **Individual** | **API key & secret (OAuth)** | User creates API key/secret at web.dhan.co. Your app does: (1) Generate consent, (2) Browser login, (3) Consume consent to get `accessToken` and `expiryTime`. Implement this flow in your app; then pass the token to the gem via `access_token` or `access_token_provider`. |
| **Partner** | **Partner consent flow** | You have `partner_id` and `partner_secret`. Your app does: (1) Generate consent, (2) User logs in on browser, (3) Consume consent to get `accessToken`. Implement in your app; pass the token to the gem. |

**What the gem provides:** It accepts a token (static or from a provider), sends it on every request, and can retry once on 401 when you use `access_token_provider`. It also provides **`DhanHQ::Auth.renew_token`** for refreshing **web-generated** tokens (RenewToken API). It does **not** implement API key/secret consent or Partner consent; use Dhan’s docs and your own HTTP client for those.

For full details and curl examples, see [DhanHQ API docs](https://dhanhq.co/docs) (Authentication).

## Static token (default)

Set `access_token` once; it is sent on every request:

```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token = ENV["DHAN_ACCESS_TOKEN"]
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

## RenewToken (web-generated tokens only)

If the token was **generated from Dhan Web** (not API key flow), you can refresh it (24h validity) using Dhan’s RenewToken API. The gem provides a helper:

```ruby
# Returns a hash with API response (e.g. accessToken, expiryTime). Use the new token for subsequent requests.
response = DhanHQ::Auth.renew_token(current_access_token, client_id)
new_token = response["accessToken"] || response[:accessToken]
# Optional: response may include "expiryTime"
```

Use this inside `access_token_provider` or in `on_token_expired` to refresh and then return the new token (e.g. store it and return it from the provider on the next request).

Example: refresh in provider and cache the result until near expiry:

```ruby
# Pseudocode: store current token + expiry; in provider, refresh if expired or near expiry
config.access_token_provider = lambda do
  stored = YourTokenStore.current
  if stored.nil? || stored.expired_soon?
    response = DhanHQ::Auth.renew_token(stored&.access_token || ENV["DHAN_ACCESS_TOKEN"], config.client_id)
    YourTokenStore.update!(response["accessToken"], response["expiryTime"])
    stored = YourTokenStore.current
  end
  raise "Token missing" unless stored
  stored.access_token
end
```

**Note:** RenewToken is only for tokens generated from Dhan Web. For API key or Partner flows, obtain a new token using Dhan’s consent APIs in your app.

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
- [GUIDE.md](../GUIDE.md) — Dynamic access token and RenewToken
- [rails_integration.md](rails_integration.md) — Rails initializer with optional `access_token_provider` and RenewToken
- [TESTING_GUIDE.md](TESTING_GUIDE.md) — Config examples and RenewToken
- [CHANGELOG.md](../CHANGELOG.md) — 2.2.0 and 2.2.1 auth and token changes


# SUPPORTED AUTHENTICATION AND TOKEN GENERATION APPROACHES:

We now support five distinct authentication approaches in this gem.

1️⃣ Static token (manual, simplest)
What: You paste a token you got from Dhan (web, OAuth, partner, whatever) into config.
How:
```ruby
DhanHQ.configure do |config|
  config.client_id    = ENV["DHAN_CLIENT_ID"]
  config.access_token = ENV["DHAN_ACCESS_TOKEN"]
end
```
When: You’re OK rotating tokens manually (e.g. cron job, ops runbook).

2️⃣ Dynamic token via access_token_provider
What: Gem asks you for a token on every request (proc/lambda).
How:
```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token_provider = -> { MyTokenStore.fetch_current_token }
  config.on_token_expired = ->(error) { MyTokenStore.refresh!(error) }
end
```
Behavior:
On 401 (auth failure), client calls on_token_expired, then retries once using a fresh token from access_token_provider.

3️⃣ Fetch-from-token-endpoint (configure_from_token_endpoint)
What: Gem calls your HTTP endpoint once to get access_token + client_id.
How:
```ruby
DhanHQ.configure_from_token_endpoint(
  base_url:    "https://myapp.com",
  bearer_token: ENV["DHAN_TOKEN_ENDPOINT_BEARER"]
)
# expects JSON: { access_token: "...", client_id: "...", base_url: "..." (optional) }
```
When: Multi-tenant or central credential service, you don’t want tokens in ENV directly.

4️⃣ TOTP-based token generation (new DhanHQ::Auth flow)
Module API (low-level)
What: Direct call to Dhan’s generateAccessToken endpoint using TOTP.
```ruby
totp = DhanHQ::Auth.generate_totp(ENV["DHAN_TOTP_SECRET"])
response = DhanHQ::Auth.generate_access_token(
  dhan_client_id: ENV["DHAN_CLIENT_ID"],
  pin:           ENV["DHAN_PIN"],
  totp:          totp
)
token  = response["accessToken"]
expiry = response["expiryTime"]
```

Client API (high-level, returns TokenResponse)
```
client = DhanHQ::Client.new(api_type: :order_api)
token = client.generate_access_token(
  dhan_client_id: ENV["DHAN_CLIENT_ID"],
  pin:           ENV["DHAN_PIN"],
  totp_secret:   ENV["DHAN_TOTP_SECRET"] # or `totp:` if you computed it
)
# auto-applies token + client_id to `DhanHQ.configuration`
```

When: Fully automated individual setup (no manual web token generation).

5️⃣ Auto token lifecycle management (TokenManager)
What: Gem handles generate + renew + retry around every API call.
How:
```ruby
client = DhanHQ::Client.new(api_type: :order_api)
client.enable_auto_token_management!(
  dhan_client_id: ENV["DHAN_CLIENT_ID"],
  pin:           ENV["DHAN_PIN"],
  totp_secret:   ENV["DHAN_TOTP_SECRET"]
)
# From now on, `client.request` auto-ensures a valid token.
```
Behavior:
On first use: calls TOTP TokenGenerator → applies token.
Before each request: ensure_valid_token!:
If no token → generate.
If needs_refresh? → TokenRenewal (POST /v2/RenewToken) with current token + dhanClientId.
If renewal fails with auth error → falls back to full generate.

6️⃣ Web-token renewal only (RenewToken)
Module API:
```ruby
response = DhanHQ::Auth.renew_token(
  access_token: current_token,
  client_id:    ENV["DHAN_CLIENT_ID"]
)
```
Client / manager (high-level):

`client.renew_access_token` (returns TokenResponse, updates config).
`TokenManager#refresh!` internally uses Auth::TokenRenewal.
When: You’re using web-generated 24h tokens and want to extend them without switching to TOTP.

TL;DR
Manual: Static token (access_token)

Dynamic: access_token_provider (+ optional on_token_expired)

Central service: configure_from_token_endpoint

Fully automated: TOTP generate (Auth / Client#generate_access_token)

Production-grade automation: enable_auto_token_management! (generate + renew)

If you tell me your exact deployment style (single user box, multi-user SaaS, on-prem, etc.), I can tell you which one you should actually use and what to delete as overkill.