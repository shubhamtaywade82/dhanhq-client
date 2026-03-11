#!/usr/bin/env ruby
# frozen_string_literal: true

# Calls every REST endpoint exposed by the DhanHQ gem via the public Model API.
# Use for connectivity checks, sandbox verification, or endpoint coverage.
#
# Usage:
#   bin/call_all_endpoints.rb              # read-only (GET + safe POST for data APIs)
#   bin/call_all_endpoints.rb --all        # include write/destructive endpoints (requires DHAN_SANDBOX=true)
#   bin/call_all_endpoints.rb --list       # print endpoint list and exit
#   bin/call_all_endpoints.rb --skip-unavailable  # skip endpoints that often 404/timeout in production
#
# Write endpoints (--all) can be tested safely in sandbox. They are only run when DHAN_SANDBOX=true.
#
# Requires DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN (or token endpoint). Optional:
#   DHAN_SANDBOX=true
#   DHAN_READ_TIMEOUT=15  DHAN_CONNECT_TIMEOUT=5  (script defaults; avoid long hangs)
#   DHAN_TEST_SECURITY_ID=11536
#   DHAN_TEST_ORDER_ID=...
#   DHAN_TEST_ISIN=...
#   DHAN_TEST_EXPIRY=YYYY-MM-DD
# When not using --skip-unavailable, the script creates a temporary alert for GET/PUT/DELETE alert endpoints and deletes it at exit.

require "optparse"
require "json"
require "date"
require "logger"
require "timeout"
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
  all: false,
  list: false,
  json: false,
  verbose: false,
  skip_unavailable: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: bin/call_all_endpoints.rb [options]"
  opts.on("--all", "Include write/destructive endpoints (requires DHAN_SANDBOX=true; safe to test in sandbox)") { options[:all] = true }
  opts.on("--list", "Print all endpoints and exit") { options[:list] = true }
  opts.on("--json", "Output results as JSON") { options[:json] = true }
  opts.on("--verbose", "Print each result summary") { options[:verbose] = true }
  opts.on("--skip-unavailable", "Skip endpoints that often 404/timeout in production (e.g. alerts, edis/tpin, forever/orders/{id})") { options[:skip_unavailable] = true }
end.parse!

puts "DhanHQ — Call all endpoints"
$stdout.flush

load_dotenv
# Lower timeouts so a slow/hanging endpoint (e.g. margin in sandbox) doesn't block the whole run.
ENV["DHAN_READ_TIMEOUT"] ||= "15"
ENV["DHAN_CONNECT_TIMEOUT"] ||= "5"
DhanHQ.ensure_configuration!
if DhanHQ.configuration.access_token.to_s.empty? && DhanHQ.configuration.client_id.to_s.empty?
  endpoint_base = ENV.fetch("DHAN_TOKEN_ENDPOINT_BASE_URL", nil)
  endpoint_bearer = ENV.fetch("DHAN_TOKEN_ENDPOINT_BEARER", nil)
  DhanHQ.configure_from_token_endpoint(base_url: endpoint_base, bearer_token: endpoint_bearer) if endpoint_base.to_s != "" && endpoint_bearer.to_s != ""
end

if options[:all] && !DhanHQ.configuration&.sandbox?
  puts "Write endpoints require sandbox. Set DHAN_SANDBOX=true to test them."
  exit 1
end

# Suppress gem ERROR logs (e.g. JSON parse errors when API returns HTML); script reports failures in its summary.
DhanHQ.logger.level = Logger::FATAL

# Defaults for params (weekday to satisfy date validations)
def next_weekday(date)
  date += 1 until date.wday.between?(1, 5)
  date
end

today = Date.today
from_date = next_weekday(today - 14).strftime("%Y-%m-%d")
to_date = next_weekday(today - 1).strftime("%Y-%m-%d")
expiry_date = ENV["DHAN_TEST_EXPIRY"] || next_weekday(today + 7).strftime("%Y-%m-%d")
security_id = ENV["DHAN_TEST_SECURITY_ID"] || "11536"
order_id = ENV["DHAN_TEST_ORDER_ID"] || "1"
forever_order_id = ENV.fetch("DHAN_TEST_FOREVER_ORDER_ID", nil)
super_order_id = ENV.fetch("DHAN_TEST_SUPER_ORDER_ID", nil)
alert_id = ENV["DHAN_TEST_ALERT_ID"] || "1"
sample_isin = ENV.fetch("DHAN_TEST_ISIN", nil)
client_id = DhanHQ.configuration&.client_id

# Alert params for creating a temporary alert (used for GET/PUT/DELETE alert endpoints); cleaned up at end.
def alert_create_params(security_id:, expiry_date:)
  {
    condition: {
      security_id: security_id,
      exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
      comparison_type: DhanHQ::Constants::ComparisonType::PRICE_WITH_VALUE,
      operator: DhanHQ::Constants::Operator::GREATER_THAN,
      comparing_value: 1,
      time_frame: DhanHQ::Constants::ALERT_TIMEFRAMES.first,
      exp_date: expiry_date,
      frequency: "ONCE"
    },
    orders: [{ transaction_type: DhanHQ::Constants::TransactionType::BUY, exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, product_type: DhanHQ::Constants::ProductType::CNC, order_type: DhanHQ::Constants::OrderType::LIMIT, security_id: security_id, quantity: 1, validity: DhanHQ::Constants::Validity::DAY, price: 1.0 }]
  }
end
created_alert_id = nil

# Minimal payloads for data/market endpoints
LTP_PARAMS = { DhanHQ::Constants::ExchangeSegment::IDX_I => [13] }.freeze
HISTORICAL_PARAMS = {
  security_id: "11536",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  instrument: DhanHQ::Constants::InstrumentType::EQUITY,
  expiry_code: DhanHQ::Constants::ExpiryCode::CURRENT,
  oi: false,
  from_date: nil,
  to_date: nil
}.freeze
# Option chain: UnderlyingScrip (int), UnderlyingSeg (CHART_EXCHANGE_SEGMENTS), Expiry (YYYY-MM-DD) for fetch; no Expiry for expirylist.
OPTION_CHAIN_PARAMS = {
  underlying_scrip: 13,
  underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I,
  expiry: nil
}.freeze
EXPIRED_OPTIONS_PARAMS = {
  exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  interval: "1",
  security_id: 13,
  instrument: DhanHQ::Constants::InstrumentType::OPTIDX,
  expiry_flag: "MONTH",
  expiry_code: DhanHQ::Constants::ExpiryCode::NEXT,
  strike: "ATM",
  drv_option_type: DhanHQ::Constants::OptionType::CALL,
  required_data: %w[open high low close],
  from_date: nil,
  to_date: nil
}.freeze
MARGIN_PARAMS = {
  dhan_client_id: nil,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: 1,
  product_type: DhanHQ::Constants::ProductType::CNC,
  security_id: "11536",
  price: 1.0,
  trigger_price: 0.0
}.freeze

# Paths skipped when --skip-unavailable (often 404 or timeout in production).
SKIP_UNAVAILABLE_PATHS = [
  "GET /v2/forever/orders/{id}",
  "GET /v2/ip/getIP",
  "GET /edis/tpin",
  "GET /alerts/orders",
  "GET /alerts/orders/{id}"
].freeze
# Write paths skipped when --skip-unavailable (reserved for future use).
SKIP_UNAVAILABLE_WRITE_PATHS = [].freeze

# Build list of [ path, name, write?, block ]
def endpoint_list(from_date:, to_date:, expiry_date:, order_id:, client_id:, **options)
  sample_isin = options[:sample_isin]
  forever_order_id = options[:forever_order_id]
  alert_id = options[:alert_id]
  h_params = HISTORICAL_PARAMS.merge(from_date: from_date, to_date: to_date)
  oc_params = OPTION_CHAIN_PARAMS.merge(expiry: expiry_date)
  eo_params = EXPIRED_OPTIONS_PARAMS.merge(from_date: from_date, to_date: to_date)
  margin_p = MARGIN_PARAMS.merge(dhan_client_id: client_id)
  oc_expiries = [] # filled by expirylist block, reused by optionchain block

  [
    ["GET /v2/profile", "Profile.fetch", false, -> { DhanHQ::Models::Profile.fetch }],
    ["GET /v2/fundlimit", "Funds.fetch", false, -> { DhanHQ::Models::Funds.fetch }],
    ["GET /v2/ledger", "LedgerEntry.all", false, -> { DhanHQ::Models::LedgerEntry.all(from_date: from_date, to_date: to_date) }],
    ["GET /v2/trades/{from}/{to}/{page}", "Trade.history", false, lambda {
      DhanHQ::Models::Trade.history(from_date: from_date, to_date: to_date, page: 0)
    }],
    ["GET /v2/orders", "Order.all", false, -> { DhanHQ::Models::Order.all }],
    ["GET /v2/orders/{id}", "Order.find", false, -> { DhanHQ::Models::Order.find(order_id) }],
    ["GET /v2/positions", "Position.all", false, -> { DhanHQ::Models::Position.all }],
    ["GET /v2/holdings", "Holding.all", false, -> { DhanHQ::Models::Holding.all }],
    ["GET /v2/trades", "Trade.today", false, -> { DhanHQ::Models::Trade.today }],
    ["GET /v2/trades/{order_id}", "Trade.find_by_order_id", false, -> { DhanHQ::Models::Trade.find_by_order_id(order_id) }],
    ["GET /v2/forever/orders", "ForeverOrder.all", false, -> { DhanHQ::Models::ForeverOrder.all }],
    ["GET /v2/forever/orders/{id}", "ForeverOrder.find", false, -> { DhanHQ::Models::ForeverOrder.find(forever_order_id || order_id) }],
    ["GET /v2/super/orders", "SuperOrder.all", false, -> { DhanHQ::Models::SuperOrder.all }],
    ["GET /v2/killswitch", "KillSwitch.status", false, -> { DhanHQ::Models::KillSwitch.status }],
    ["GET /v2/ip/getIP", "IPSetup.current", false, -> { DhanHQ::Resources::IPSetup.new.current }],
    ["GET /edis/tpin", "Edis.generate_tpin", false, -> { DhanHQ::Models::Edis.generate_tpin }],
    ["GET /alerts/orders", "AlertOrder.all", false, -> { DhanHQ::Models::AlertOrder.all }],
    ["GET /alerts/orders/{id}", "AlertOrder.find", false, -> { DhanHQ::Models::AlertOrder.find(alert_id) }],
    ["GET /v2/pnlExit", "PnlExit.status", false, -> { DhanHQ::Models::PnlExit.status }],
    ["POST /v2/marketfeed/ltp", "MarketFeed.ltp", false, -> { DhanHQ::Models::MarketFeed.ltp(LTP_PARAMS) }],
    ["POST /v2/marketfeed/ohlc", "MarketFeed.ohlc", false, -> { DhanHQ::Models::MarketFeed.ohlc(LTP_PARAMS) }],
    ["POST /v2/marketfeed/quote", "MarketFeed.quote", false, -> { DhanHQ::Models::MarketFeed.quote(LTP_PARAMS) }],
    ["POST /v2/optionchain/expirylist", "OptionChain.fetch_expiry_list", false, lambda {
      oc_expiries.replace(DhanHQ::Models::OptionChain.fetch_expiry_list(oc_params.except(:expiry)))
    }],
    ["POST /v2/optionchain", "OptionChain.fetch", false, lambda {
      resolved_expiry = oc_expiries.first || expiry_date
      DhanHQ::Models::OptionChain.fetch(oc_params.merge(expiry: resolved_expiry))
    }],
    ["POST /v2/charts/historical", "HistoricalData.daily", false, -> { DhanHQ::Models::HistoricalData.daily(h_params) }],
    ["POST /v2/charts/intraday", "HistoricalData.intraday", false, -> { DhanHQ::Models::HistoricalData.intraday(h_params.merge(interval: "5")) }],
    ["POST /v2/charts/rollingoption", "ExpiredOptionsData.fetch", false, -> { DhanHQ::Models::ExpiredOptionsData.fetch(eo_params) }],
    ["POST /v2/margincalculator", "Margin.calculate", false, -> { DhanHQ::Models::Margin.calculate(margin_p) }],
    ["POST /v2/margincalculator/multi", "Margin.calculate_multi", false, lambda {
      DhanHQ::Models::Margin.calculate_multi(dhan_client_id: client_id, include_position: false, include_order: false, scrip_list: [{ exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, transaction_type: DhanHQ::Constants::TransactionType::BUY, quantity: 1, product_type: DhanHQ::Constants::ProductType::CNC, security_id: "11536", price: 1.0, trigger_price: 0.0 }])
    }],
    ["GET /v2/instrument/{segment}", "Instrument.by_segment", false, -> { DhanHQ::Models::Instrument.by_segment(DhanHQ::Constants::ExchangeSegment::NSE_EQ) }],
    ["GET /edis/inquire/{isin}", "Edis.inquire", false, -> { sample_isin ? DhanHQ::Models::Edis.inquire(isin: sample_isin) : (raise "Set DHAN_TEST_ISIN") }]
  ]
end

def write_endpoints(client_id:, security_id:, order_id:, forever_order_id:, super_order_id:, alert_id:, expiry_date:)
  order_params = {
    transaction_type: DhanHQ::Constants::TransactionType::BUY,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    product_type: DhanHQ::Constants::ProductType::INTRADAY,
    order_type: DhanHQ::Constants::OrderType::LIMIT,
    validity: DhanHQ::Constants::Validity::DAY,
    security_id: security_id,
    quantity: 1,
    price: 1.0,
    disclosed_quantity: 0,
    after_market_order: false
  }
  alert_params = alert_create_params(security_id: security_id, expiry_date: expiry_date)
  alert_condition = alert_params[:condition]
  alert_orders = alert_params[:orders]
  position_convert_params = { dhan_client_id: client_id, from_product_type: DhanHQ::Constants::ProductType::INTRADAY, to_product_type: DhanHQ::Constants::ProductType::CNC, exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, position_type: DhanHQ::Constants::PositionType::LONG, security_id: security_id, trading_symbol: "TCS", convert_qty: 1 }
  forever_params = {
    dhan_client_id: client_id,
    order_flag: DhanHQ::Constants::OrderFlag::OCO,
    transaction_type: DhanHQ::Constants::TransactionType::BUY,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    product_type: DhanHQ::Constants::ProductType::CNC,
    order_type: DhanHQ::Constants::OrderType::LIMIT,
    validity: DhanHQ::Constants::Validity::DAY,
    security_id: security_id,
    quantity: 1,
    price: 1.0,
    trigger_price: 0.9,
    price1: 1.2,
    trigger_price1: 1.1,
    quantity1: 1
  }
  forever_modify_params = {
    order_flag: DhanHQ::Constants::OrderFlag::SINGLE,
    order_type: DhanHQ::Constants::OrderType::LIMIT,
    leg_name: DhanHQ::Constants::LegName::TARGET_LEG,
    quantity: 1,
    price: 1.0,
    trigger_price: 0.9,
    validity: DhanHQ::Constants::Validity::DAY
  }
  super_params = { transaction_type: DhanHQ::Constants::TransactionType::BUY, exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, product_type: DhanHQ::Constants::ProductType::INTRADAY, order_type: DhanHQ::Constants::OrderType::LIMIT, security_id: security_id, quantity: 1, price: 1.0, target_price: 1.5, stop_loss_price: 0.5, trailing_jump: 0.1 }

  [
    ["POST /v2/orders", "Order.place", -> { DhanHQ::Models::Order.place(order_params) }],
    ["PUT /v2/orders/{id}", "Order.modify", -> { DhanHQ::Models::Order.find(order_id).modify(quantity: 1, price: 1.0) }],
    ["DELETE /v2/orders/{id}", "Order.cancel", -> { DhanHQ::Models::Order.find(order_id).cancel }],
    ["POST /v2/positions/convert", "Position.convert", -> { DhanHQ::Models::Position.convert(position_convert_params) }],
    ["DELETE /v2/positions", "Position.exit_all!", -> { DhanHQ::Models::Position.exit_all! }],
    ["POST /v2/killswitch", "KillSwitch.activate", -> { DhanHQ::Models::KillSwitch.activate }],
    ["POST /v2/pnlExit", "PnlExit.configure", -> { DhanHQ::Models::PnlExit.configure(profit_value: 1000, loss_value: 500, product_type: %w[INTRADAY CNC], enable_kill_switch: false) }],
    ["DELETE /v2/pnlExit", "PnlExit.stop", -> { DhanHQ::Models::PnlExit.stop }],
    ["POST /alerts/orders", "AlertOrder.create", -> { DhanHQ::Models::AlertOrder.create(condition: alert_condition, orders: alert_orders) }],
    ["PUT /alerts/orders/{id}", "AlertOrder.modify", -> { DhanHQ::Models::AlertOrder.modify(alert_id, condition: alert_condition, orders: alert_orders) }],
    ["DELETE /alerts/orders/{id}", "AlertOrder.destroy", -> { DhanHQ::Models::AlertOrder.find(alert_id)&.destroy }],
    ["POST /v2/forever/orders", "ForeverOrder.create", -> { DhanHQ::Models::ForeverOrder.create(forever_params) }],
    ["PUT /v2/forever/orders/{id}", "ForeverOrder.modify", -> { DhanHQ::Models::ForeverOrder.find(forever_order_id || order_id).modify(forever_modify_params) }],
    ["DELETE /v2/forever/orders/{id}", "ForeverOrder.cancel", -> { DhanHQ::Models::ForeverOrder.find(forever_order_id || order_id).cancel }],
    ["POST /v2/super/orders", "SuperOrder.create", -> { DhanHQ::Models::SuperOrder.create(super_params) }],
    ["PUT /v2/super/orders/{id}", "SuperOrder.modify", -> { DhanHQ::Models::SuperOrder.find(super_order_id || order_id).modify(price: 1.0, quantity: 1) }],
    ["DELETE /v2/super/orders/{id}/{leg}", "SuperOrder.cancel", -> { DhanHQ::Models::SuperOrder.find(super_order_id || order_id).cancel(DhanHQ::Constants::LegName::ENTRY_LEG) }]
  ]
end

if options[:list]
  list = endpoint_list(from_date: from_date, to_date: to_date, expiry_date: expiry_date, order_id: order_id, client_id: client_id, sample_isin: sample_isin, forever_order_id: forever_order_id, alert_id: alert_id)
  list = list.reject { |path, *_| SKIP_UNAVAILABLE_PATHS.include?(path) } if options[:skip_unavailable]
  list.each { |path, name, write| puts "#{write ? "[W]" : "[R]"} #{path}  (#{name})" }
  if options[:all]
    w_list = write_endpoints(
      client_id: client_id,
      security_id: security_id,
      order_id: order_id, forever_order_id: forever_order_id, super_order_id: super_order_id, alert_id: alert_id,
      expiry_date: expiry_date
    )
    w_list = w_list.reject { |path, *_| SKIP_UNAVAILABLE_WRITE_PATHS.include?(path) } if options[:skip_unavailable]
    w_list.each { |path, name, _| puts "[W] #{path}  (#{name})" }
  end
  exit 0
end

# Create a temporary alert so GET/PUT/DELETE alert endpoints have a valid ID (removed in ensure below).
# If create fails (e.g. 404 in production where Conditional Trigger may be unavailable), continue without one.
unless options[:skip_unavailable]
  begin
    created = DhanHQ::Models::AlertOrder.create(alert_create_params(security_id: security_id, expiry_date: expiry_date))
    if created&.alert_id
      alert_id = created.alert_id.to_s
      created_alert_id = alert_id
    end
  rescue StandardError
    # Alert create failed; alert_id stays ENV or "1"; GET/PUT/DELETE alert endpoints may 404
  end
end

begin
  results = []

  def run(results, path, name, write:, progress: false, &)
    print "  #{path} ... " if progress
    $stdout.flush if progress
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(25, &)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    results << { path: path, name: name, write: write, status: "ok", duration_ms: duration_ms }
    puts "ok (#{duration_ms}ms)" if progress
  rescue Timeout::Error
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    results << { path: path, name: name, write: write, status: "error", duration_ms: duration_ms, error: "Timeout::Error: request timed out after 25s" }
    puts "error" if progress
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    msg = e.message.to_s.gsub(/\s+/, " ").strip
    msg = "#{msg[0, 380]}..." if msg.length > 380
    err_display = "#{e.class.name.split("::").last}: #{msg}"
    results << { path: path, name: name, write: write, status: "error", duration_ms: duration_ms, error: err_display }
    puts "error" if progress
  end

  list = endpoint_list(from_date: from_date, to_date: to_date, expiry_date: expiry_date, order_id: order_id, client_id: client_id, sample_isin: sample_isin, forever_order_id: forever_order_id, alert_id: alert_id)
  skipped_count = 0
  if options[:skip_unavailable]
    skipped_count = list.count { |path, *_| SKIP_UNAVAILABLE_PATHS.include?(path) }
    list = list.reject { |path, *_| SKIP_UNAVAILABLE_PATHS.include?(path) }
  end
  progress = !options[:json]
  if progress
    puts "Calling #{list.size} endpoints..."
    puts "Skipped #{skipped_count} unavailable endpoint(s)." if skipped_count.positive?
    $stdout.flush
  end
  list.each do |path, name, write, blk|
    next if path.include?("edis/inquire") && sample_isin.to_s.empty?

    run(results, path, name, write: write, progress: progress, &blk)
  end

  if options[:all]
    write_list = write_endpoints(client_id: client_id, security_id: security_id, order_id: order_id, forever_order_id: forever_order_id, super_order_id: super_order_id, alert_id: alert_id,
                                 expiry_date: expiry_date)
    write_list = write_list.reject { |path, *_| SKIP_UNAVAILABLE_WRITE_PATHS.include?(path) } if options[:skip_unavailable]
    write_list = write_list.reject { |path, *_| path == "POST /alerts/orders" } if created_alert_id
    puts "Calling #{write_list.size} write endpoints..." if progress
    write_list.each do |path, name, blk|
      run(results, path, name, write: true, progress: progress, &blk)
    end
  end

  summary = { total: results.size, ok: results.count { |r| r[:status] == "ok" }, error: results.count { |r| r[:status] == "error" } }
  summary[:skipped] = skipped_count if skipped_count.positive?

  if options[:json]
    puts JSON.pretty_generate(summary: summary, results: results)
    exit(summary[:error].zero? ? 0 : 1)
  end

  puts "Sandbox: #{DhanHQ.configuration&.sandbox?}"
  puts "Read-only: #{!options[:all]}"
  puts "Skipped unavailable: #{skipped_count}" if skipped_count.positive?
  puts "-" * 60
  if options[:verbose]
    results.each do |r|
      sym = r[:status] == "ok" ? "OK" : "ERR"
      puts "[#{sym}] #{r[:path]} (#{r[:duration_ms]}ms) #{r[:error] || ""}"
    end
  else
    results.select { |r| r[:status] == "error" }.each do |r|
      puts "[ERR] #{r[:path]} — #{r[:error]}"
    end
  end
  puts "-" * 60
  puts "Total: #{summary[:total]} | OK: #{summary[:ok]} | Error: #{summary[:error]}"
  exit(summary[:error].zero? ? 0 : 1)
ensure
  DhanHQ::Models::AlertOrder.find(created_alert_id)&.destroy if created_alert_id
end
