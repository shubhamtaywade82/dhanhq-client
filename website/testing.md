---
title: DhanHQ Testing Guide — Ruby SDK
description: Testing patterns and best practices for the DhanHQ Ruby gem including sandbox usage, VCR integration, and order workflow testing.
---

# Testing & Best Practices

See the full [Testing Guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/TESTING_GUIDE.md) on GitHub for detailed testing patterns.

## Sandbox Environment

The Dhan API provides a sandbox for testing. Configure the gem to use the sandbox endpoint:

```ruby
DhanHQ.configure do |c|
  c.client_id    = ENV["DHAN_SANDBOX_CLIENT_ID"]
  c.access_token = ENV["DHAN_SANDBOX_ACCESS_TOKEN"]
  c.environment  = :sandbox
end
```

## RSpec

```ruby
require 'dhan_hq'

RSpec.describe DhanHQ::Models::Order do
  it "places an order with valid params" do
    order = DhanHQ::Models::Order.create(
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      # ...
    )
    expect(order).to be_valid
  end
end
```

## Best Practices

- Always use `correlation_id` for idempotent order placement
- Prefer WebSocket for real-time state over REST polling
- Validate order parameters before transport
- Never retry order placement automatically
- Use environment variables for credentials
