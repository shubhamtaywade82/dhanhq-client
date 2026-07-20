#!/usr/bin/env ruby
# frozen_string_literal: true
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/ParameterLists
# rubocop:disable Style/FormatString

require "date"

LOT_SIZES = {
  "NIFTY" => 75,
  "BANKNIFTY" => 15,
  "FINNIFTY" => 25,
  "MIDCPNIFTY" => 50,
  "SENSEX" => 10
}.freeze

FREEZE_QTY = {
  "NIFTY" => 1800,
  "BANKNIFTY" => 900,
  "FINNIFTY" => 1000,
  "MIDCPNIFTY" => 2800,
  "SENSEX" => 500
}.freeze

VALID_EXCHANGE_SEGMENTS = %w[
  NSE_EQ BSE_EQ NSE_FNO BSE_FNO MCX_COMM NSE_CURRENCY BSE_CURRENCY
].freeze

EQUITY_SEGMENTS = %w[NSE_EQ BSE_EQ].freeze
DERIVATIVE_SEGMENTS = %w[NSE_FNO BSE_FNO MCX_COMM NSE_CURRENCY BSE_CURRENCY].freeze

EQUITY_PRODUCT_TYPES = %w[CNC INTRADAY MARGIN MTF].freeze
DERIVATIVE_PRODUCT_TYPES = %w[INTRADAY MARGIN].freeze

VALID_ORDER_TYPES = %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET].freeze
VALID_TRANSACTION_TYPES = %w[BUY SELL].freeze
VALID_VALIDITY = %w[DAY IOC].freeze

NOTIONAL_WARNING_THRESHOLD = 50_000

def _infer_lot_size(trading_symbol)
  return nil if trading_symbol.nil? || trading_symbol.to_s.empty?

  symbol_upper = trading_symbol.to_s.upcase
  LOT_SIZES.each do |name, lot_size|
    return lot_size if symbol_upper.include?(name)
  end
  nil
end

def _infer_freeze_qty(trading_symbol)
  return nil if trading_symbol.nil? || trading_symbol.to_s.empty?

  symbol_upper = trading_symbol.to_s.upcase
  FREEZE_QTY.each do |name, freeze_qty|
    return freeze_qty if symbol_upper.include?(name)
  end
  nil
end

def validate_order(
  security_id: nil,
  exchange_segment: nil,
  transaction_type: nil,
  quantity: nil,
  order_type: nil,
  product_type: nil,
  price: 0.0,
  trigger_price: 0.0,
  validity: DhanHQ::Constants::Validity::DAY,
  after_market_order: false,
  trading_symbol: nil,
  lot_size: nil
)
  errors = []
  warnings = []

  exchange_segment = exchange_segment&.to_s&.upcase
  transaction_type = transaction_type&.to_s&.upcase
  order_type = order_type&.to_s&.upcase
  product_type = product_type&.to_s&.upcase
  validity = validity&.to_s&.upcase

  errors << "security_id is required" if security_id.nil? || security_id.to_s.empty?
  errors << "exchange_segment is required" if exchange_segment.nil? || exchange_segment.to_s.empty?
  errors << "transaction_type is required" if transaction_type.nil? || transaction_type.to_s.empty?
  errors << "quantity must be a positive integer" if quantity.nil? || quantity.to_i <= 0
  errors << "order_type is required" if order_type.nil? || order_type.to_s.empty?
  errors << "product_type is required" if product_type.nil? || product_type.to_s.empty?

  errors << "Invalid exchange_segment: #{exchange_segment}" if exchange_segment && !VALID_EXCHANGE_SEGMENTS.include?(exchange_segment)
  errors << "Invalid transaction_type: #{transaction_type}" if transaction_type && !VALID_TRANSACTION_TYPES.include?(transaction_type)
  errors << "Invalid order_type: #{order_type}" if order_type && !VALID_ORDER_TYPES.include?(order_type)
  errors << "Invalid validity: #{validity}" if validity && !VALID_VALIDITY.include?(validity)

  errors << "price is required for #{order_type} orders" if %w[LIMIT STOP_LOSS].include?(order_type) && price.to_f <= 0
  errors << "trigger_price is required for #{order_type} orders" if %w[STOP_LOSS STOP_LOSS_MARKET].include?(order_type) && trigger_price.to_f <= 0

  if exchange_segment && EQUITY_SEGMENTS.include?(exchange_segment) && product_type && !EQUITY_PRODUCT_TYPES.include?(product_type)
    errors << "Invalid product_type '#{product_type}' for equity segment '#{exchange_segment}'. Valid values: #{EQUITY_PRODUCT_TYPES.sort}"
  end

  if exchange_segment && DERIVATIVE_SEGMENTS.include?(exchange_segment) && product_type && !DERIVATIVE_PRODUCT_TYPES.include?(product_type)
    errors << "Invalid product_type '#{product_type}' for derivative segment '#{exchange_segment}'. Valid values: #{DERIVATIVE_PRODUCT_TYPES.sort}"
  end

  warnings << "Dhan's current order docs say API market orders are converted to limit orders with MPP." if order_type == DhanHQ::Constants::OrderType::MARKET

  effective_lot_size = lot_size || _infer_lot_size(trading_symbol)
  if exchange_segment && DERIVATIVE_SEGMENTS.include?(exchange_segment) && quantity
    if effective_lot_size && quantity.to_i % effective_lot_size != 0
      errors << "Derivative quantity must be a multiple of lot size #{effective_lot_size}. Got #{quantity}."
    elsif effective_lot_size.nil?
      warnings << "Could not resolve a lot size from the provided data. Confirm lot size from the security master before placing."
    end

    freeze_qty = _infer_freeze_qty(trading_symbol)
    if freeze_qty && quantity.to_i > freeze_qty
      warnings << "Quantity #{quantity} exceeds fallback freeze quantity #{freeze_qty}. Consider place_slice_order() after verifying the latest exchange freeze limits."
    end
  end

  if price.to_f.positive? && quantity
    notional = price.to_f * quantity.to_i
    warnings << "High notional value: Rs. #{"%.2f" % notional} exceeds the Rs. 50,000 warning threshold." if notional > NOTIONAL_WARNING_THRESHOLD
  end

  unless after_market_order
    now = Time.now
    if now.saturday? || now.sunday?
      warnings << "Market is closed on weekends. Use AMO only if that is intentional."
    elsif now.hour < 9 || (now.hour == 9 && now.min < 15)
      warnings << "Regular market is not yet open."
    elsif now.hour > 15 || (now.hour == 15 && now.min > 30)
      warnings << "Regular market is closed. Use AMO only if that is intentional."
    end
  end

  {
    "valid" => errors.empty?,
    "errors" => errors,
    "warnings" => warnings
  }
end

def print_validation(result)
  if result["valid"]
    puts "Order validation: PASS"
  else
    puts "Order validation: FAIL"
    result["errors"].each { |error| puts "  ERROR: #{error}" }
  end
  result["warnings"].each { |warning| puts "  WARNING: #{warning}" }
end

if __FILE__ == $PROGRAM_NAME
  sample = validate_order(
    security_id: "2885",
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    transaction_type: DhanHQ::Constants::TransactionType::BUY,
    quantity: 10,
    order_type: DhanHQ::Constants::OrderType::LIMIT,
    product_type: DhanHQ::Constants::ProductType::CNC,
    price: 2450
  )
  print_validation(sample)
end
