---
title: DhanHQ Ruby SDK — Installation & Authentication
description: Install and configure the DhanHQ Ruby gem. Learn authentication methods including static tokens, PIN + TOTP, and environment variables for the Dhan API.
---

# Getting Started

## Installation

Add to your Gemfile:

```ruby
gem 'DhanHQ'
```

Or install directly:

```bash
gem install DhanHQ
```

Requires **Ruby 3.2 or newer**.

## Configuration

```ruby
DhanHQ.configure do |c|
  c.client_id    = ENV["DHAN_CLIENT_ID"]
  c.access_token = ENV["DHAN_ACCESS_TOKEN"]
end
```

## Authentication

The gem supports multiple authentication strategies:

| Method | Description |
|--------|-------------|
| Static token | Direct `access_token` configuration |
| PIN + TOTP | Auto-generate and renew tokens via `enable_auto_token_management!` |
| Environment variables | `DHAN_CLIENT_ID` + `DHAN_ACCESS_TOKEN` |

For PIN + TOTP auto-renewal:

```ruby
DhanHQ.configure do |c|
  c.client_id = ENV["DHAN_CLIENT_ID"]
  c.access_token = ENV["DHAN_ACCESS_TOKEN"] # initial token
end

client = DhanHQ::Client.new
client.enable_auto_token_management!(
  dhan_client_id: ENV["DHAN_CLIENT_ID"],
  pin:            ENV["DHAN_PIN"],
  totp_secret:    ENV["DHAN_TOTP_SECRET"]
)
```

See the full [authentication guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/AUTHENTICATION.md) for details.
