# frozen_string_literal: true

require "dhan_hq"
require "json"
require "csv"

# Resolution helper for credentials and loading config files.
def _load_config(path)
  JSON.parse(File.read(path))
rescue StandardError
  {}
end

# Initialize the DhanHQ configuration.
def get_client(config_path = nil)
  client_id = nil
  access_token = nil

  paths_to_try = [
    config_path,
    ENV.fetch("DHAN_CONFIG_PATH", nil),
    "config.json"
  ]

  paths_to_try.each do |path|
    next if path.nil? || path.to_s.empty? || !File.exist?(path)

    config = _load_config(path)
    client_id = config["client_id"] || config[:client_id] || client_id
    access_token = config["access_token"] || config[:access_token] || access_token
    break if client_id && access_token
  end

  client_id ||= ENV.fetch("DHAN_CLIENT_ID", nil)
  access_token ||= ENV.fetch("DHAN_ACCESS_TOKEN", nil)

  if client_id.nil? || client_id.to_s.empty? || access_token.nil? || access_token.to_s.empty?
    raise ArgumentError, "Credentials not found. Set DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN, or use config.json"
  end

  DhanHQ.configure do |config|
    config.client_id = client_id.to_s
    config.access_token = access_token.to_s
  end

  DhanHQ.ensure_configuration!
end

# Extract data field or raise error if response failed.
def unwrap_sdk_data(response)
  if response.respond_to?(:key?)
    status = response[:status] || response["status"]
    remarks = response[:remarks] || response["remarks"]
    data = response[:data] || response["data"]

    raise remarks.to_s unless status == "success"

    return data
  end
  response
end

# Resolve a symbol to its security details.
def resolve_symbol(symbol, exchange_segment = DhanHQ::Constants::ExchangeSegment::NSE_EQ, _instrument_name = DhanHQ::Constants::InstrumentType::EQUITY)
  inst = DhanHQ::Models::Instrument.find(exchange_segment, symbol, exact_match: true)
  inst ||= DhanHQ::Models::Instrument.find(exchange_segment, symbol, exact_match: false)
  return nil unless inst

  {
    "security_id" => inst.security_id.to_s,
    "trading_symbol" => inst.symbol_name,
    "display_name" => inst.display_name,
    "exchange_segment" => inst.exchange_segment,
    "instrument_name" => inst.instrument
  }
end

# Resolve derivative details like Strike/Expiry/OptionType from the security list.
def resolve_derivative(underlying, strike: nil, option_type: nil, expiry: nil, exchange: "NSE")
  exchange_segment = case exchange.to_s.upcase
                     when "NSE" then DhanHQ::Constants::ExchangeSegment::NSE_FNO
                     when "BSE" then DhanHQ::Constants::ExchangeSegment::BSE_FNO
                     when "MCX" then DhanHQ::Constants::ExchangeSegment::MCX_COMM
                     else DhanHQ::Constants::ExchangeSegment::NSE_FNO
                     end

  instruments = DhanHQ::Models::Instrument.by_segment(exchange_segment)
  return nil if instruments.empty?

  matches = instruments.select do |inst|
    symbol_match = inst.underlying_symbol&.upcase == underlying.upcase ||
                   inst.symbol_name&.upcase&.start_with?(underlying.upcase)

    match = symbol_match

    match &&= inst.strike_price&.to_f == strike.to_f if strike

    if option_type
      match &&= if option_type.to_s.upcase == "FUT"
                  inst.instrument&.upcase&.include?("FUT")
                else
                  inst.option_type&.upcase == option_type.to_s.upcase
                end
    end

    match &&= inst.expiry_date == expiry if expiry

    match
  end

  matches = matches.sort_by { |inst| [inst.expiry_date.to_s, inst.symbol_name.to_s] }
  return nil if matches.empty?

  row = matches.first
  {
    "security_id" => row.security_id.to_s,
    "trading_symbol" => row.symbol_name,
    "lot_size" => row.lot_size&.to_i || 1,
    "tick_size" => row.tick_size&.to_f || 0.05,
    "expiry" => row.expiry_date,
    "instrument_name" => row.instrument
  }
end

# Fetch lot size of an instrument from common fallback table or security master.
def get_lot_size(security_id: nil, trading_symbol: nil, underlying: nil)
  common_lots = { "NIFTY" => 75, "BANKNIFTY" => 15, "FINNIFTY" => 25, "MIDCPNIFTY" => 50, "SENSEX" => 10 }

  if underlying
    name = underlying.upcase.gsub(/\s+/, "")
    return common_lots[name] if common_lots.key?(name)
  end

  if trading_symbol
    name = trading_symbol.upcase
    common_lots.each { |k, v| return v if name.include?(k) }
  end

  # Lookup instrument via segment
  if security_id
    %w[NSE_EQ NSE_FNO IDX_I].each do |seg|
      insts = begin
        DhanHQ::Models::Instrument.by_segment(seg)
      rescue StandardError
        []
      end
      inst = insts.find { |i| i.security_id.to_s == security_id.to_s }
      return inst.lot_size.to_i if inst&.lot_size
    end
  end

  if trading_symbol
    inst = DhanHQ::Models::Instrument.find_anywhere(trading_symbol)
    return inst.lot_size.to_i if inst&.lot_size
  end

  nil
end

# Build a human-readable order preview.
def preview_order(security_id:, exchange_segment:, transaction_type:, quantity:, order_type:, product_type:, price: 0.0, trading_symbol: nil)
  notional = price.to_f * quantity.to_i
  lines = [
    "--- ORDER PREVIEW ---",
    "Security:     #{trading_symbol || security_id}",
    "Exchange:     #{exchange_segment}",
    "Action:       #{transaction_type}",
    "Quantity:     #{quantity}",
    "Order Type:   #{order_type}",
    "Product Type: #{product_type}",
    "Price:        #{order_type.to_s.upcase == DhanHQ::Constants::OrderType::MARKET ? "MARKET / MPP" : "Rs. #{"%.2f" % price}"}"
  ]
  if notional.positive? && order_type.to_s.upcase != DhanHQ::Constants::OrderType::MARKET
    lines << "Notional:     Rs. #{"%.2f" % notional}"
    lines << "Warning:      Notional exceeds Rs. 50,000" if notional > 50_000
  end
  lines << "---------------------"
  lines.join("\n")
end

# Normalize option-chain data format.
def normalize_option_chain(response)
  data = response[:data] || response["data"] || response

  if data.key?(:strikes) || data.key?("strikes")
    spot = data[:last_price] || data["last_price"]
    strikes = data[:strikes] || data["strikes"]

    rows = strikes.map do |s|
      strike = s[:strike] || s["strike"]
      ce = s[:call] || s["call"] || {}
      pe = s[:put] || s["put"] || {}

      row = { "strike" => strike.to_f }

      # ce fields
      row["ce_security_id"] = ce["security_id"] || ce[:security_id]
      row["ce_ltp"] = ce["last_price"] || ce[:last_price]
      row["ce_avg_price"] = ce["average_price"] || ce[:average_price]
      row["ce_oi"] = ce["oi"] || ce[:oi]
      row["ce_oi_change"] = ce["oi_change"] || ce[:oi_change]
      row["ce_volume"] = ce["volume"] || ce[:volume]
      row["ce_iv"] = ce["implied_volatility"] || ce[:implied_volatility]
      row["ce_bid_price"] = ce["top_bid_price"] || ce[:top_bid_price]
      row["ce_bid_qty"] = ce["top_bid_quantity"] || ce[:top_bid_quantity]
      row["ce_ask_price"] = ce["top_ask_price"] || ce[:top_ask_price]
      row["ce_ask_qty"] = ce["top_ask_quantity"] || ce[:top_ask_quantity]

      ce_greeks = ce["greeks"] || ce[:greeks] || {}
      row["ce_delta"] = ce_greeks["delta"] || ce_greeks[:delta]
      row["ce_gamma"] = ce_greeks["gamma"] || ce_greeks[:gamma]
      row["ce_theta"] = ce_greeks["theta"] || ce_greeks[:theta]
      row["ce_vega"] = ce_greeks["vega"] || ce_greeks[:vega]

      # pe fields
      row["pe_security_id"] = pe["security_id"] || pe[:security_id]
      row["pe_ltp"] = pe["last_price"] || pe[:last_price]
      row["pe_avg_price"] = pe["average_price"] || pe[:average_price]
      row["pe_oi"] = pe["oi"] || pe[:oi]
      row["pe_oi_change"] = pe["oi_change"] || pe[:oi_change]
      row["pe_volume"] = pe["volume"] || pe[:volume]
      row["pe_iv"] = pe["implied_volatility"] || pe[:implied_volatility]
      row["pe_bid_price"] = pe["top_bid_price"] || pe[:top_bid_price]
      row["pe_bid_qty"] = pe["top_bid_quantity"] || pe[:top_bid_quantity]
      row["pe_ask_price"] = pe["top_ask_price"] || pe[:top_ask_price]
      row["pe_ask_qty"] = pe["top_ask_quantity"] || pe[:top_ask_quantity]

      pe_greeks = pe["greeks"] || pe[:greeks] || {}
      row["pe_delta"] = pe_greeks["delta"] || pe_greeks[:delta]
      row["pe_gamma"] = pe_greeks["gamma"] || pe_greeks[:gamma]
      row["pe_theta"] = pe_greeks["theta"] || pe_greeks[:theta]
      row["pe_vega"] = pe_greeks["vega"] || pe_greeks[:vega]

      row
    end

    return spot.to_f, rows
  end

  [0.0, []]
end

# Fetch option-chain and return the rows.
def fetch_chain_df(_dhan_client = nil, under_security_id:, expiry:, under_exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I)
  chain = DhanHQ::Models::OptionChain.fetch(
    underlying_scrip: under_security_id.to_i,
    underlying_seg: under_exchange_segment,
    expiry: expiry
  )
  normalize_option_chain(chain)
end

# Find ATM row nearest to spot.
def find_atm_row(chain_rows, spot)
  chain_rows.min_by { |row| (row["strike"].to_f - spot.to_f).abs }
end

# Aggregate holdings and positions into summary.
def format_pnl_report(holdings = nil, positions = nil)
  holdings_list = holdings || begin
    DhanHQ::Models::Holding.all
  rescue StandardError
    []
  end
  positions_list = positions || begin
    DhanHQ::Models::Position.all
  rescue StandardError
    []
  end

  report = {
    "total_investment" => 0.0,
    "current_value" => 0.0,
    "total_pnl" => 0.0,
    "day_pnl" => 0.0,
    "holdings_count" => holdings_list.size,
    "positions_count" => positions_list.size
  }

  holdings_list.each do |holding|
    qty = holding.respond_to?(:total_qty) ? holding.total_qty : (holding[:totalQty] || holding["totalQty"] || 0)
    cost = holding.respond_to?(:avg_cost_price) ? holding.avg_cost_price : (holding[:avgCostPrice] || holding["avgCostPrice"] || 0)
    val = holding.respond_to?(:market_value) ? holding.market_value : (holding[:marketValue] || holding["marketValue"] || 0)
    pnl = holding.respond_to?(:pnl) ? holding.pnl : (holding[:pnl] || holding["pnl"] || 0)
    day_pnl = holding.respond_to?(:day_pnl) ? holding.day_pnl : (holding[:dayPnl] || holding["dayPnl"] || 0)

    report["total_investment"] += cost.to_f * qty.to_f
    report["current_value"] += val.to_f
    report["total_pnl"] += pnl.to_f
    report["day_pnl"] += day_pnl.to_f
  end

  positions_list.each do |position|
    realized = position.respond_to?(:realized_profit) ? position.realized_profit : (position[:realizedProfit] || position["realizedProfit"] || 0)
    unrealized = position.respond_to?(:unrealized_profit) ? position.unrealized_profit : (position[:unrealizedProfit] || position["unrealizedProfit"] || 0)
    report["total_pnl"] += realized.to_f + unrealized.to_f
  end

  report
end

# Run pre-flight margin checks against Dhan API.
def check_margin(_dhan_client = nil, security_id:, exchange_segment:, transaction_type:, quantity:, product_type:, price:, trigger_price: 0.0)
  margin = DhanHQ::Models::Margin.calculate(
    security_id: security_id.to_s,
    exchange_segment: exchange_segment,
    transaction_type: transaction_type,
    quantity: quantity,
    product_type: product_type,
    price: price,
    trigger_price: trigger_price
  )
  DhanHQ::Models::Funds.fetch

  {
    "total_margin" => margin.total_margin.to_f,
    "available_balance" => margin.available_balance.to_f,
    "brokerage" => margin.brokerage.to_f,
    "leverage" => margin.leverage.to_f,
    "sufficient" => margin.available_balance.to_f >= margin.total_margin.to_f,
    "shortfall" => [0.0, margin.total_margin.to_f - margin.available_balance.to_f].max
  }
end
