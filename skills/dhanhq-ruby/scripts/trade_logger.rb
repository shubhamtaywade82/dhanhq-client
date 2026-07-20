# frozen_string_literal: true
# rubocop:disable Style/FormatStringToken
# rubocop:disable Naming/AccessorMethodName

require "json"
require "fileutils"
require "date"

def _get_log_path
  plugin_data = ENV.fetch("CLAUDE_PLUGIN_DATA", nil)
  if plugin_data && !plugin_data.empty?
    FileUtils.mkdir_p(plugin_data)
    File.join(plugin_data, "trades.jsonl")
  else
    default_dir = File.expand_path("../data", __dir__)
    FileUtils.mkdir_p(default_dir)
    File.join(default_dir, "trades.jsonl")
  end
end

def log_order(order_params, response, notes = "")
  log_path = _get_log_path
  FileUtils.mkdir_p(File.dirname(log_path))

  status = response[:status] || response["status"]
  data = response[:data] || response["data"]
  order_id = data.is_a?(Hash) ? (data[:orderId] || data["orderId"]) : nil

  record = {
    "timestamp" => Time.now.strftime("%Y-%m-%dT%H:%M:%S%:z"),
    "order_params" => order_params,
    "response" => response,
    "order_id" => order_id,
    "status" => status,
    "notes" => notes
  }

  File.open(log_path, "a") do |f|
    f.write("#{JSON.dump(record)}\n")
  end

  record
end

def _read_all_records
  log_path = _get_log_path
  return [] unless File.exist?(log_path)

  records = []
  File.foreach(log_path) do |line|
    line_trimmed = line.strip
    next if line_trimmed.empty?

    records << JSON.parse(line_trimmed)
  rescue JSON::ParserError
    # skip invalid lines
  end
  records
end

def get_today_orders
  today_str = begin
    Date.today.isoformat
  rescue StandardError
    Date.today.strftime("%Y-%m-%d")
  end
  _read_all_records.select { |r| r["timestamp"].start_with?(today_str) }
end

def get_trade_history(days = 7)
  cutoff_time = Time.now - (days * 24 * 60 * 60)
  cutoff_str = cutoff_time.strftime("%Y-%m-%dT%H:%M:%S%:z")

  records = _read_all_records.select { |r| r["timestamp"] >= cutoff_str }
  records.sort_by { |r| r["timestamp"] }.reverse
end

def get_trade_summary(days = 7)
  records = get_trade_history(days)
  summary = {
    "period_days" => days,
    "total_orders" => records.size,
    "successful" => records.count { |r| r["status"] == "success" },
    "failed" => records.count { |r| r["status"] != "success" },
    "buy_count" => 0,
    "sell_count" => 0,
    "instruments_traded" => []
  }

  instruments = []
  records.each do |r|
    params = r["order_params"] || {}
    txn = params["transaction_type"] || params[:transaction_type] || ""
    if txn.to_s.upcase == DhanHQ::Constants::TransactionType::BUY
      summary["buy_count"] += 1
    elsif txn.to_s.upcase == DhanHQ::Constants::TransactionType::SELL
      summary["sell_count"] += 1
    end

    sid = params["security_id"] || params[:security_id] || params["trading_symbol"] || params[:trading_symbol]
    instruments << sid.to_s if sid
  end

  summary["instruments_traded"] = instruments.uniq
  summary
end

def print_today_orders
  orders = get_today_orders
  if orders.empty?
    puts "No orders placed today."
    return
  end

  puts "--- Today's Orders (#{orders.size} total) ---"
  orders.each do |r|
    params = r["order_params"] || {}
    status = r["status"] || "unknown"
    oid = r["order_id"] || "N/A"
    txn = params["transaction_type"] || params[:transaction_type] || "?"
    sym = params["trading_symbol"] || params[:trading_symbol] || params["security_id"] || params[:security_id] || "?"
    qty = params["quantity"] || params[:quantity] || "?"
    price = params["price"] || params[:price] || "MKT"

    time_part = r["timestamp"].split("T")[1] ? r["timestamp"].split("T")[1][0...8] : "00:00:00"

    printf("  [%s] %-8s | %-4s %dx %s @ %s | ID: %s\n", time_part, status.to_s.upcase, txn.to_s.upcase, qty, sym, price, oid)
  end
end

print_today_orders if __FILE__ == $PROGRAM_NAME
