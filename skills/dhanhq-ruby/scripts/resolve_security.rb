# frozen_string_literal: true
# rubocop:disable Style/FormatStringToken
# rubocop:disable Performance/CollectionLiteralInLoop

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "dhan_helpers"

def load_security_master(_segment = "compact")
  puts "Loading security master segments..."
  # Unlike Python, Ruby SDK by_segment is segment-specific.
  # We will resolve dynamically when searching.
end

def search_equity(query, limit = 10)
  query_upper = query.to_s.upcase.strip

  results = []
  %w[NSE_EQ BSE_EQ].each do |segment|
    instruments = begin
      DhanHQ::Models::Instrument.by_segment(segment)
    rescue StandardError
      []
    end
    instruments.each do |inst|
      next unless inst.instrument == DhanHQ::Constants::InstrumentType::EQUITY

      symbol_name = inst.symbol_name.to_s.upcase
      underlying = inst.underlying_symbol.to_s.upcase
      display_name = inst.display_name.to_s.upcase

      if symbol_name == query_upper || display_name == query_upper
        results << inst
      elsif symbol_name.include?(query_upper) || display_name.include?(query_upper) || underlying.include?(query_upper)
        results << inst
      end

      break if results.size >= limit
    end
    break if results.size >= limit
  end
  begin
    results.head(limit)
  rescue StandardError
    results.first(limit)
  end
end

def search_derivative(underlying, strike: nil, option_type: nil, expiry: nil, limit: 20)
  # Look in NSE_FNO and BSE_FNO
  results = []
  %w[NSE_FNO BSE_FNO].each do |segment|
    instruments = begin
      DhanHQ::Models::Instrument.by_segment(segment)
    rescue StandardError
      []
    end
    matched = instruments.select do |inst|
      symbol_match = inst.underlying_symbol&.upcase == underlying.upcase ||
                     inst.symbol_name&.upcase&.start_with?(underlying.upcase)

      match = symbol_match

      if option_type == "FUT"
        match &&= inst.instrument&.upcase&.include?("FUT")
      elsif %w[CE PE].include?(option_type)
        match &&= inst.option_type&.upcase == option_type
      end

      match &&= inst.strike_price&.to_f == strike.to_f if strike

      match &&= inst.expiry_date == expiry if expiry

      match
    end

    results.concat(matched)
  end

  results.sort_by { |inst| [inst.expiry_date.to_s, inst.symbol_name.to_s] }.first(limit)
end

def parse_query(query)
  parts = query.upcase.split

  return { type: :equity, name: query } if parts.size <= 2 && parts.none? { |p| %w[CE PE FUT FUTURE].include?(p) }

  underlying = parts[0]
  strike = nil
  option_type = nil
  expiry = nil

  parts[1..].each do |part|
    if %w[CE PE].include?(part)
      option_type = part
    elsif %w[FUT FUTURE].include?(part)
      option_type = "FUT"
    elsif part.include?("-") && part.length == 10
      expiry = part
    else
      begin
        strike = Float(part)
      rescue ArgumentError
        underlying += " #{part}"
      end
    end
  end

  {
    type: :fno,
    underlying: underlying,
    strike: strike,
    option_type: option_type,
    expiry: expiry
  }
end

def main
  if ARGV.empty?
    puts "Usage: ruby scripts/resolve_security.rb <query>"
    puts "Examples: \"RELIANCE\", \"HDFC Bank\", \"NIFTY 24000 CE 2025-03-27\""
    exit 1
  end

  query = ARGV.join(" ")
  parsed = parse_query(query)

  # Ensure configuration is initialized (can be dummy if just reading files)
  begin
    DhanHQ.configure_with_env
  rescue StandardError
    nil
  end

  results = if parsed[:type] == :equity
              search_equity(parsed[:name])
            else
              search_derivative(
                parsed[:underlying],
                strike: parsed[:strike],
                option_type: parsed[:option_type],
                expiry: parsed[:expiry]
              )
            end

  if results.empty?
    puts "No instruments found for: #{query}"
    return
  end

  puts "\nResults for: #{query}\n\n"
  printf("%-15s | %-18s | %-12s | %-12s | %-6s | %-10s\n", "Security ID", "Trading Symbol", "Exchange Seg", "Instrument", "Lot", "Expiry")
  puts "-" * 85
  results.each do |row|
    printf(
      "%-15s | %-18s | %-12s | %-12s | %-6d | %-10s\n",
      row.security_id.to_s,
      row.symbol_name.to_s,
      row.exchange_segment.to_s,
      row.instrument.to_s,
      row.lot_size.to_i,
      row.expiry_date.to_s
    )
  end
  puts
end

main if __FILE__ == $PROGRAM_NAME
