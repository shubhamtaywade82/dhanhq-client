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

Or with a block:

```ruby
client = DhanHQ::Client.new(
  client_id: ENV["DHAN_CLIENT_ID"],
  access_token: ENV["DHAN_ACCESS_TOKEN"]
)
```

## Authentication

The gem supports multiple authentication strategies:

| Method | Description |
|--------|-------------|
| Static token | Direct `access_token` configuration |
| PIN + TOTP | Auto-generate and renew tokens |
| Environment variables | `DHAN_CLIENT_ID` + `DHAN_ACCESS_TOKEN` |

For PIN + TOTP auto-renewal:

```ruby
DhanHQ.configure do |c|
  c.client_id = ENV["DHAN_CLIENT_ID"]
  c.pin       = ENV["DHAN_PIN"]
  c.totp_secret = ENV["DHAN_TOTP_SECRET"]
end
```

See the full [authentication guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/AUTHENTICATION.md) for details.

## Rails Quick Start

```bash
rails generate dhan_hq:install
```

This creates `config/initializers/dhan_hq.rb` and a binstub.
