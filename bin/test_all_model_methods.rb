#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "json"
require "date"
require "logger"
require_relative "../lib/dhan_hq"

def load_dotenv(path = ".env")
  return unless File.exist?(path)

  File.readlines(path, chomp: true).each do |line|
    next if line.strip.empty? || line.strip.start_with?("#")
    next unless line.include?("=")

    key, value = line.split("=", 2)
    key = key.to_s.strip
    value = value.to_s.strip.gsub(/\A['"]|['"]\z/, "")
    next if key.empty?
    next if ENV.key?(key)

    ENV[key] = value
  end
end

options = {
  include_write: false,
  json: false,
  fail_fast_auth: true,
  verbose: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: bin/test_all_model_methods.rb [options]"
  opts.on("--include-write", "Run state-changing APIs (may place/cancel/modify real orders)") { options[:include_write] = true }
  opts.on("--json", "Print raw JSON output") { options[:json] = true }
  opts.on("--no-fail-fast-auth", "Do not stop early when auth is invalid") { options[:fail_fast_auth] = false }
  opts.on("--verbose", "Print every method result") { options[:verbose] = true }
end.parse!

load_dotenv
DhanHQ.configure_with_env
if DhanHQ.configuration.access_token.to_s.empty? || DhanHQ.configuration.client_id.to_s.empty?
  endpoint_base = ENV.fetch("DHAN_TOKEN_ENDPOINT_BASE_URL", nil)
  endpoint_bearer = ENV.fetch("DHAN_TOKEN_ENDPOINT_BEARER", nil)
  DhanHQ.configure_from_token_endpoint(base_url: endpoint_base, bearer_token: endpoint_bearer) if endpoint_base.to_s != "" && endpoint_bearer.to_s != ""
end

# Reduce noisy SDK warnings during bulk method execution.
DhanHQ.logger.level = Logger::ERROR

client_id = DhanHQ.configuration.client_id
from_date = (Date.today - 7).strftime("%Y-%m-%d")
to_date = Date.today.strftime("%Y-%m-%d")
expiry_date = ENV["DHAN_TEST_EXPIRY"] || (Date.today + 30).strftime("%Y-%m-%d")

sample_security_id = ENV["DHAN_TEST_SECURITY_ID"] || "11536"
sample_order_id = ENV["DHAN_TEST_ORDER_ID"] || "123456789"
ENV["DHAN_TEST_FOREVER_ORDER_ID"] || sample_order_id
ENV["DHAN_TEST_SUPER_ORDER_ID"] || sample_order_id
sample_alert_id = ENV["DHAN_TEST_ALERT_ID"] || "1"
sample_isin = ENV.fetch("DHAN_TEST_ISIN", nil)
sample_symbol = ENV["DHAN_TEST_SYMBOL"] || "TCS"
sample_correlation_id = ENV.fetch("DHAN_TEST_CORRELATION_ID", nil)

order_full_params = {
  dhan_client_id: client_id,
  correlation_id: "codex-smoke-#{Time.now.to_i}",
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type: DhanHQ::Constants::ProductType::INTRADAY,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  validity: DhanHQ::Constants::Validity::DAY,
  security_id: sample_security_id,
  quantity: 1,
  disclosed_quantity: 0,
  price: 1.0,
  after_market_order: false
}

super_order_params = {
  dhan_client_id: client_id,
  correlation_id: "codex-super-#{Time.now.to_i}",
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type: DhanHQ::Constants::ProductType::INTRADAY,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  security_id: sample_security_id,
  quantity: 1,
  price: 1.0,
  target_price: 1.5,
  stop_loss_price: 0.5,
  trailing_jump: 0.1
}

forever_order_params = {
  dhan_client_id: client_id,
  correlation_id: "codex-forever-#{Time.now.to_i}",
  order_flag: DhanHQ::Constants::OrderFlag::OCO,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type: DhanHQ::Constants::ProductType::CNC,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  validity: DhanHQ::Constants::Validity::DAY,
  security_id: sample_security_id,
  quantity: 1,
  disclosed_quantity: 0,
  price: 1.0,
  trigger_price: 0.9,
  price1: 1.2,
  trigger_price1: 1.1,
  quantity1: 1
}

alert_order_params = {
  condition: {
    security_id: sample_security_id,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    comparison_type: DhanHQ::Constants::ComparisonType::PRICE_WITH_VALUE,
    operator: DhanHQ::Constants::Operator::GREATER_THAN,
    comparing_value: 1.0,
    exp_date: (Date.today + 365).strftime("%Y-%m-%d"),
    frequency: "ONCE"
  },
  orders: [
    {
      transaction_type: DhanHQ::Constants::TransactionType::BUY,
      exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
      product_type: DhanHQ::Constants::ProductType::CNC,
      order_type: DhanHQ::Constants::OrderType::LIMIT,
      security_id: sample_security_id,
      quantity: 1,
      validity: DhanHQ::Constants::Validity::DAY,
      price: 1.0,
      trigger_price: 0.0
    }
  ]
}

margin_full_params = {
  dhan_client_id: client_id,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: 1,
  product_type: DhanHQ::Constants::ProductType::CNC,
  security_id: sample_security_id,
  price: 1.0,
  trigger_price: 0.0
}

expired_options_params = {
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_FNO,
  interval: "1",
  security_id: 13,
  instrument: DhanHQ::Constants::InstrumentType::OPTIDX,
  expiry_flag: "MONTH",
  expiry_code: DhanHQ::Constants::ExpiryCode::NEXT,
  strike: "ATM",
  drv_option_type: DhanHQ::Constants::OptionType::CALL,
  required_data: %w[open high low close iv volume strike oi spot],
  from_date: from_date,
  to_date: to_date
}

results = []

def execute(results, name, write: false, skip_if: nil)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    value = yield
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    summary = case value
              when NilClass then "nil"
              when Array then "Array(size=#{value.size})"
              when Hash then "Hash(keys=#{value.keys.first(5).map(&:inspect).join(", ")})"
              else value.class.to_s
              end
    results << { name: name, write: write, status: "ok", duration_ms: duration_ms, result: summary }
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    msg = e.message.to_s.gsub(/\s+/, " ").strip
    if skip_if&.call(e)
      results << { name: name, write: write, status: "skipped", duration_ms: duration_ms, error: "#{e.class}: #{msg[0, 260]}" }
      return
    end
    issue = if e.class.to_s.match?(/Authentication|Token/) || msg.match?(/access[_\s-]?token|client[_\s-]?id|unauthor|auth/i)
              "auth"
            elsif e.class.to_s.include?("Validation") || msg.match?(/validation|invalid|required|missing/i)
              "validation"
            elsif e.class.to_s.match?(/Network|Faraday/) || msg.match?(/network|connect|timeout|socket|dns|ssl/i)
              "network"
            else
              "other"
            end
    results << { name: name, write: write, status: "error", duration_ms: duration_ms, issue: issue, error_class: e.class.to_s, error: msg[0, 260] }
  end
end

def skip(results, name, reason, write: false)
  results << { name: name, write: write, status: "skipped", error: reason }
end

def auth_error?(error)
  klass = error.class.to_s
  msg = error.message.to_s
  klass.match?(/Authentication|Token|InvalidClientID|InvalidAccess/) ||
    msg.match?(/401|unauthor|invalid token|invalid client|access[_\s-]?token|client[_\s-]?id/i)
end

if options[:fail_fast_auth]
  begin
    DhanHQ::Models::Profile.fetch
  rescue StandardError => e
    if auth_error?(e)
      warn("AUTH PREFLIGHT FAILED: #{e.class}: #{e.message}")
      warn("Check DHAN_TOKEN_ENDPOINT_BASE_URL / DHAN_TOKEN_ENDPOINT_BEARER output and verify it returns current {access_token, client_id}.")
      warn("Tip: run with --no-fail-fast-auth if you still want the full per-method report.")
      exit(2)
    end
  end
end

# Read-only / low-risk methods
execute(results, "Profile.fetch") { DhanHQ::Models::Profile.fetch }
execute(results, "Funds.fetch") { DhanHQ::Models::Funds.fetch }
execute(results, "Funds.balance") { DhanHQ::Models::Funds.balance }
holdings = []
execute(results, "Holding.all") { holdings = DhanHQ::Models::Holding.all }
execute(results, "Position.all") { DhanHQ::Models::Position.all }
execute(results, "Position.active") { DhanHQ::Models::Position.active }
orders = []
execute(results, "Order.all") { orders = DhanHQ::Models::Order.all }
execute(results, "Order.find") { DhanHQ::Models::Order.find(sample_order_id) }
if sample_correlation_id.to_s.empty?
  skip(results, "Order.find_by_correlation", "Set DHAN_TEST_CORRELATION_ID to test this method with a real correlation id.")
else
  execute(results, "Order.find_by_correlation") { DhanHQ::Models::Order.find_by_correlation(sample_correlation_id) }
end
execute(results, "Trade.today") { DhanHQ::Models::Trade.today }
execute(results, "Trade.find_by_order_id") { DhanHQ::Models::Trade.find_by_order_id(sample_order_id) }
execute(results, "Trade.history") { DhanHQ::Models::Trade.history(from_date: from_date, to_date: to_date, page: 0) }
execute(results, "HistoricalData.daily") do
  DhanHQ::Models::HistoricalData.daily(
    security_id: sample_security_id,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    instrument: DhanHQ::Constants::InstrumentType::EQUITY,
    expiry_code: DhanHQ::Constants::ExpiryCode::CURRENT,
    oi: false,
    from_date: from_date,
    to_date: to_date
  )
end
execute(results, "HistoricalData.intraday") do
  DhanHQ::Models::HistoricalData.intraday(
    security_id: sample_security_id,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    instrument: DhanHQ::Constants::InstrumentType::EQUITY,
    interval: "5",
    expiry_code: DhanHQ::Constants::ExpiryCode::CURRENT,
    oi: false,
    from_date: from_date,
    to_date: to_date
  )
end
execute(results, "MarketFeed.ltp") { DhanHQ::Models::MarketFeed.ltp({ DhanHQ::Constants::ExchangeSegment::IDX_I => [13] }) }
execute(results, "MarketFeed.ohlc") { DhanHQ::Models::MarketFeed.ohlc({ DhanHQ::Constants::ExchangeSegment::IDX_I => [13] }) }
execute(results, "MarketFeed.quote") { DhanHQ::Models::MarketFeed.quote({ DhanHQ::Constants::ExchangeSegment::IDX_I => [13] }) }
option_expiries = []
execute(results, "OptionChain.fetch_expiry_list") do
  option_expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(underlying_scrip: 13, underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I)
end
resolved_expiry = option_expiries.first || expiry_date
if resolved_expiry.to_s.empty?
  skip(results, "OptionChain.fetch", "No expiry available from OptionChain.fetch_expiry_list")
else
  execute(results, "OptionChain.fetch") do
    DhanHQ::Models::OptionChain.fetch(underlying_scrip: 13, underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I, expiry: resolved_expiry)
  end
end
execute(results, "ExpiredOptionsData.fetch") { DhanHQ::Models::ExpiredOptionsData.fetch(expired_options_params) }
execute(results, "Margin.calculate") { DhanHQ::Models::Margin.calculate(margin_full_params) }
execute(results, "Margin.calculate_multi") do
  DhanHQ::Models::Margin.calculate_multi(
    include_position: false,
    include_order: false,
    dhan_client_id: client_id,
    scrip_list: [
      {
        exchangeSegment: margin_full_params[:exchange_segment],
        transactionType: margin_full_params[:transaction_type],
        quantity: margin_full_params[:quantity],
        productType: margin_full_params[:product_type],
        securityId: margin_full_params[:security_id],
        price: margin_full_params[:price],
        triggerPrice: margin_full_params[:trigger_price]
      }
    ]
  )
end
execute(results, "LedgerEntry.all") { DhanHQ::Models::LedgerEntry.all(from_date: from_date, to_date: to_date) }
execute(results, "KillSwitch.status") { DhanHQ::Models::KillSwitch.status }
execute(results, "PnlExit.status") { DhanHQ::Models::PnlExit.status }
execute(results, "IPSetup.current", skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) { DhanHQ::Resources::IPSetup.new.current }
execute(results, "TraderControl.status", skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) { DhanHQ::Resources::TraderControl.new.status }
execute(results, "AlertOrder.all", skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) { DhanHQ::Models::AlertOrder.all }
execute(results, "AlertOrder.find", skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) { DhanHQ::Models::AlertOrder.find(sample_alert_id) }
forever_orders = []
execute(results, "ForeverOrder.all") { forever_orders = DhanHQ::Models::ForeverOrder.all }
resolved_forever_order_id = ENV["DHAN_TEST_FOREVER_ORDER_ID"] || forever_orders.first&.order_id
if resolved_forever_order_id.to_s.empty?
  skip(results, "ForeverOrder.find", "No forever order available. Set DHAN_TEST_FOREVER_ORDER_ID.")
else
  execute(results, "ForeverOrder.find", skip_if: ->(e) { e.is_a?(DhanHQ::InputExceptionError) }) { DhanHQ::Models::ForeverOrder.find(resolved_forever_order_id) }
end
execute(results, "SuperOrder.all") { DhanHQ::Models::SuperOrder.all }
resolved_isin = sample_isin
if resolved_isin.to_s.empty? && holdings.any?
  resolved_isin = holdings.map { |h| h.respond_to?(:isin) ? h.isin.to_s : "" }.find { |v| !v.empty? }
end
if resolved_isin.to_s.empty?
  skip(results, "Edis.inquire", "No ISIN available. Set DHAN_TEST_ISIN or keep at least one holding with ISIN.")
else
  execute(results, "Edis.inquire") { DhanHQ::Models::Edis.inquire(isin: resolved_isin) }
end
execute(results, "Instrument.by_segment") { DhanHQ::Models::Instrument.by_segment(DhanHQ::Constants::ExchangeSegment::NSE_EQ) }
execute(results, "Instrument.find") { DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, sample_symbol) }
execute(results, "Instrument.find_anywhere") { DhanHQ::Models::Instrument.find_anywhere(sample_symbol) }
execute(results, "Instrument.normalize_csv_row") do
  DhanHQ::Models::Instrument.normalize_csv_row({ "EXCH_ID" => "NSE", "SEGMENT" => "E", "SECURITY_ID" => sample_security_id, "SYMBOL_NAME" => sample_symbol,
                                                 "INSTRUMENT" => DhanHQ::Constants::InstrumentType::EQUITY })
end
execute(results, "Postback.parse") { DhanHQ::Models::Postback.parse({ orderStatus: DhanHQ::Constants::OrderStatus::PENDING, orderId: "1" }.to_json) }
execute(results, "OrderUpdate.from_websocket_message") do
  DhanHQ::Models::OrderUpdate.from_websocket_message(
    orderNo: "1",
    orderStatus: DhanHQ::Constants::OrderStatus::PENDING,
    transactionType: DhanHQ::Constants::TransactionType::BUY,
    orderType: DhanHQ::Constants::OrderType::LIMIT,
    productType: DhanHQ::Constants::ProductType::CNC,
    exchangeSegment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    quantity: 1,
    tradedQty: 0,
    price: 1.0
  )
end

if options[:include_write]
  execute(results, "Order.place", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::OrderError) && e.message.to_s.include?("Market is Closed") }) { DhanHQ::Models::Order.place(order_full_params) }
  execute(results, "Order.create", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::OrderError) && e.message.to_s.include?("Market is Closed") }) { DhanHQ::Models::Order.create(order_full_params) }
  execute(results, "Position.convert", write: true, skip_if: ->(e) { e.message.to_s.include?("Market is Closed") }) do
    DhanHQ::Models::Position.convert(
      dhan_client_id: client_id,
      from_product_type: DhanHQ::Constants::ProductType::INTRADAY,
      to_product_type: DhanHQ::Constants::ProductType::CNC,
      exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
      position_type: DhanHQ::Constants::PositionType::LONG,
      security_id: sample_security_id,
      trading_symbol: sample_symbol,
      convert_qty: 1
    )
  end
  execute(results, "Position.exit_all!", write: true) { DhanHQ::Models::Position.exit_all! }
  execute(results, "KillSwitch.update", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::InputExceptionError) }) { DhanHQ::Models::KillSwitch.update("ACTIVATE") }
  execute(results, "KillSwitch.activate", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::InputExceptionError) }) { DhanHQ::Models::KillSwitch.activate }
  execute(results, "KillSwitch.deactivate", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::InputExceptionError) }) { DhanHQ::Models::KillSwitch.deactivate }
  execute(results, "PnlExit.configure", write: true) do
    DhanHQ::Models::PnlExit.configure(
      profit_value: 1000.0,
      loss_value: 500.0,
      product_type: [DhanHQ::Constants::ProductType::INTRADAY, DhanHQ::Constants::ProductType::CNC],
      enable_kill_switch: false
    )
  end
  execute(results, "PnlExit.stop", write: true) { DhanHQ::Models::PnlExit.stop }
  execute(results, "AlertOrder.create", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) { DhanHQ::Models::AlertOrder.create(alert_order_params) }
  execute(results, "AlertOrder.modify", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) do
    DhanHQ::Models::AlertOrder.modify(
      sample_alert_id,
      condition: alert_order_params[:condition].merge(comparing_value: 1.1),
      orders: alert_order_params[:orders]
    )
  end
  execute(results, "SuperOrder.create", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::OrderError) && e.message.to_s.include?("Market is Closed") }) { DhanHQ::Models::SuperOrder.create(super_order_params) }
  execute(results, "ForeverOrder.create", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::InputExceptionError) }) { DhanHQ::Models::ForeverOrder.create(forever_order_params) }
  execute(results, "Edis.generate_tpin", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::InternalServerError) }) { DhanHQ::Models::Edis.generate_tpin }
  if sample_isin.to_s.strip.empty?
    skip(results, "Edis.generate_form", "DHAN_TEST_ISIN not set", write: true)
    skip(results, "Edis.generate_bulk_form", "DHAN_TEST_ISIN not set", write: true)
  else
    execute(results, "Edis.generate_form", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) || e.is_a?(DhanHQ::InputExceptionError) }) do
      DhanHQ::Models::Edis.generate_form(isin: sample_isin, qty: 1, exchange: "NSE", segment: "E", bulk: false)
    end
    execute(results, "Edis.generate_bulk_form", write: true, skip_if: ->(e) { e.is_a?(DhanHQ::NotFoundError) }) do
      DhanHQ::Models::Edis.generate_bulk_form(
        securities: [{ isin: sample_isin, qty: 1, exchange: "NSE", segment: "E" }]
      )
    end
  end
else
  results << {
    name: "WRITE_METHODS_SKIPPED",
    write: true,
    status: "skipped",
    error: "Run with --include-write to execute state-changing model methods."
  }
end

summary = {
  total: results.size,
  ok: results.count { |r| r[:status] == "ok" },
  error: results.count { |r| r[:status] == "error" },
  skipped: results.count { |r| r[:status] == "skipped" },
  errors_by_issue: results.select { |r| r[:status] == "error" }.group_by { |r| r[:issue] }.transform_values(&:count)
}

output = {
  env: {
    dhan_client_id_set: !ENV["DHAN_CLIENT_ID"].to_s.empty?,
    dhan_access_token_set: !ENV["DHAN_ACCESS_TOKEN"].to_s.empty?,
    configured_client_id: !DhanHQ.configuration.client_id.to_s.empty?,
    configured_access_token: !DhanHQ.configuration.access_token.to_s.empty?
  },
  options: options,
  summary: summary,
  results: results
}

if options[:json]
  puts JSON.pretty_generate(output)
  exit(summary[:error].zero? ? 0 : 1)
end

puts "DhanHQ Model Methods Test"
puts "=" * 80
puts "Client ID set: #{output[:env][:configured_client_id]} | Access Token set: #{output[:env][:configured_access_token]}"
puts "Include write methods: #{options[:include_write]}"
puts "-" * 80

if options[:verbose]
  results.each do |r|
    if r[:status] == "ok"
      puts "[OK] #{r[:name]} (#{r[:duration_ms]}ms) => #{r[:result]}"
    elsif r[:status] == "skipped"
      puts "[SKIP] #{r[:name]} => #{r[:error]}"
    else
      puts "[ERR] #{r[:name]} (#{r[:duration_ms]}ms) [#{r[:issue]}] #{r[:error_class]}: #{r[:error]}"
    end
  end
else
  failed = results.select { |r| r[:status] == "error" }
  skipped = results.select { |r| r[:status] == "skipped" }
  if failed.empty?
    puts "No failed methods."
  else
    puts "Failed methods:"
    failed.each do |r|
      puts "- #{r[:name]} [#{r[:issue]}] #{r[:error_class]}: #{r[:error]}"
    end
  end
  skipped.each do |r|
    puts "- #{r[:name]} (skipped): #{r[:error]}"
  end
end
puts "-" * 80
puts "Summary: total=#{summary[:total]} ok=#{summary[:ok]} error=#{summary[:error]} skipped=#{summary[:skipped]}"
puts "Errors by issue: #{summary[:errors_by_issue]}"

exit(summary[:error].zero? ? 0 : 1)
