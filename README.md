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
end
```

Alternatively, set credentials from environment variables:

```ruby
DhanHQ.configure_with_env
```

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

## 🔹 Available Resources

| Resource     | Model                 | Actions                                             |
| ------------ | --------------------- | --------------------------------------------------- |
| Orders       | `DhanHQ::Order`       | `find`, `all`, `where`, `place`, `update`, `cancel` |
| Positions    | `DhanHQ::Position`    | `all`, `find`, `exit!`                              |
| Trades       | `DhanHQ::Trade`       | `all`, `find`                                       |
| Option Chain | `DhanHQ::OptionChain` | `fetch`, `fetch_expiry_list`                        |
| Market Feeds | `DhanHQ::MarketFeed`  | `ltp, ohlc`, `quote`                                |
| Portfolio    | `DhanHQ::Portfolio`   | `holdings`, `positions`                             |
| Funds        | `DhanHQ::Funds`       | `fund_limit`, `margin_calculator`                   |

## 📌 Development

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
🔗 https://github.com/shubhamtaywade82/dhanhq

This project follows a code of conduct to maintain a safe and welcoming community.

## 📌 License

This gem is available under the MIT License.
🔗 https://opensource.org/licenses/MIT

## 📌 Code of Conduct

Everyone interacting in the DhanHQ project is expected to follow the
🔗 Code of Conduct.

```markdown
This **README.md** file is structured and formatted for **GitHub** or any **Markdown-compatible** documentation system. 🚀
```
