# DhanHQ - Ruby Client for DhanHQ API

DhanHQ is a **Ruby client** for interacting with **Dhan API v2.0**. It provides **ActiveRecord-like** behavior, **RESTful resource management**, and **ActiveModel validation** for seamless integration into **algorithmic trading applications**.

## ⚡ Features

✅ **ORM-like Interface** (`find`, `all`, `where`, `save`, `update`, `destroy`)
✅ **ActiveModel Integration** (`validations`, `errors`, `serialization`)
✅ **Resource Objects for Trading** (`Orders`, `Positions`, `Holdings`, etc.)
✅ **Supports WebSockets for Market Feeds**
✅ **Error Handling & Validations** (`ActiveModel::Errors`)
✅ **DRY & Modular Code** (`Helpers`, `Contracts`, `Request Handling`)

---

## 📌 Installation

Add this line to your application's Gemfile:

```bash
gem 'dhanhq'
```

Then execute:

```
bundle install
```

Or install it manually:

```
gem install dhanhq
```

🔹 Configuration
Set your DhanHQ API credentials:

```ruby
DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
  # Optional: override the default API endpoint
  config.base_url = "https://api.dhan.co/v2"
end
```

Use `config.base_url` to point the client at a different API URL (for example, a sandbox).

Alternatively, set credentials from environment variables:

```ruby
DhanHQ.configure_with_env
```

`configure_with_env` expects the following environment variables:

* `CLIENT_ID`
* `ACCESS_TOKEN`

Create a `.env` file in your project root to supply these values:

```dotenv
CLIENT_ID=your_client_id
ACCESS_TOKEN=your_access_token
```

The gem requires `dotenv/load`, so these variables are loaded automatically when you require `dhanhq`.

## 🚀 Usage

✅ Placing an Order

```ruby
order = DhanHQ::Order.new(
  transaction_type: "BUY",
  exchange_segment: "NSE_FNO",
  product_type: "MARGIN",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "43492",
  quantity: 125,
  price: 100.0
)

order.save
puts order.persisted? # true
```

✅ Fetching an Order

```ruby
order = DhanHQ::Order.find("452501297117")
puts order.price # Current price of the order
```

✅ Updating an Order

```ruby
order.update(price: 105.0)
puts order.price # 105.0
```

✅ Canceling an Order

```ruby
order.cancel
```

✅ Fetching All Orders

```ruby
orders = DhanHQ::Order.all
puts orders.count
```

✅ Querying Orders

```ruby
pending_orders = DhanHQ::Order.where(status: "PENDING")
puts pending_orders.first.order_id
```

✅ Exiting Positions

```ruby
positions = DhanHQ::Position.all
position = positions.first
position.exit!
```

### Orders

#### Place

```ruby
order = DhanHQ::Order.new(transaction_type: "BUY", security_id: "123", quantity: 1)
order.save
```

#### Modify

```ruby
order.modify(price: 102.5)
```

#### Cancel

```ruby
order.cancel
```

### Trades

```ruby
DhanHQ::Trade.today
DhanHQ::Trade.find_by_order_id("452501297117")
```

### Positions

```ruby
positions = DhanHQ::Position.all
active = DhanHQ::Position.active
DhanHQ::Position.convert(position_id: "1", product_type: "CNC")
```

### Holdings

```ruby
DhanHQ::Holding.all
```

### Funds

```ruby
DhanHQ::Funds.fetch
balance = DhanHQ::Funds.balance
```

### Option Chain

```ruby
DhanHQ::OptionChain.fetch(security_id: "1333", expiry_date: "2024-06-30")
DhanHQ::OptionChain.fetch_expiry_list(security_id: "1333")
```

### Historical Data

```ruby
DhanHQ::HistoricalData.daily(security_id: "1333", from_date: "2024-01-01", to_date: "2024-01-31")
DhanHQ::HistoricalData.intraday(security_id: "1333", interval: "15")
```

## 🔹 Available Resources

| Resource                 | Model                            | Actions                                             |
| ------------------------ | -------------------------------- | --------------------------------------------------- |
| Orders                   | `DhanHQ::Models::Order`          | `find`, `all`, `where`, `place`, `update`, `cancel` |
| Trades                   | `DhanHQ::Models::Trade`          | `all`, `find_by_order_id`                           |
| Forever Orders           | `DhanHQ::Models::ForeverOrder`   | `create`, `find`, `modify`, `cancel`, `all`         |
| Holdings                 | `DhanHQ::Models::Holding`        | `all`                                               |
| Positions                | `DhanHQ::Models::Position`       | `all`, `find`, `exit!`                              |
| Funds & Margin           | `DhanHQ::Models::Funds`          | `fund_limit`, `margin_calculator`                   |
| Ledger                   | `DhanHQ::Models::Ledger`         | `all`                                               |
| Market Feeds             | `DhanHQ::Models::MarketFeed`     | `ltp, ohlc`, `quote`                                |
| Historical Data (Charts) | `DhanHQ::Models::HistoricalData` | `daily`, `intraday`                                 |
| Option Chain             | `DhanHQ::Models::OptionChain`    | `fetch`, `fetch_expiry_list`                        |

## 📌 Development

Set `DHAN_DEBUG=true` to log HTTP requests during development:

```bash
export DHAN_DEBUG=true
```

Running Tests

```bash
bundle exec rspec
```

Installing Locally

```bash
bundle exec rake install
```

Releasing a New Version

```bash
bundle exec rake release
```

## 📌 Contributing

Bug reports and pull requests are welcome on GitHub at:
🔗 <https://github.com/shubhamtaywade82/dhanhq>

This project follows a code of conduct to maintain a safe and welcoming community.

## 📌 License

This gem is available under the MIT License.
🔗 <https://opensource.org/licenses/MIT>

## 📌 Code of Conduct

Everyone interacting in the DhanHQ project is expected to follow the
🔗 Code of Conduct.

```markdown
This **README.md** file is structured and formatted for **GitHub** or any **Markdown-compatible** documentation system. 🚀
```
