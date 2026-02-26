# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module DhanHQ
      # Enforces the use of `DhanHQ::Constants` instead of hardcoded strings.
      #
      # @example
      #   # bad
      #   transaction_type: "BUY"
      #
      #   # good
      #   transaction_type: DhanHQ::Constants::TransactionType::BUY
      class UseConstants < Base
        extend AutoCorrector

        MSG = "Use `%<constant>s` instead of hardcoded string `%<string>s`."

        CONSTANTS_MAP = {
          "SELL" => "DhanHQ::Constants::TransactionType::SELL",
          "BUY" => "DhanHQ::Constants::TransactionType::BUY",
          "LIMIT" => "DhanHQ::Constants::OrderType::LIMIT",
          "MARKET" => "DhanHQ::Constants::OrderType::MARKET",
          "STOP_LOSS" => "DhanHQ::Constants::OrderType::STOP_LOSS",
          "STOP_LOSS_MARKET" => "DhanHQ::Constants::OrderType::STOP_LOSS_MARKET",
          "IOC" => "DhanHQ::Constants::Validity::IOC",
          "DAY" => "DhanHQ::Constants::Validity::DAY",
          "TRANSIT" => "DhanHQ::Constants::OrderStatus::TRANSIT",
          "PENDING" => "DhanHQ::Constants::OrderStatus::PENDING",
          "CLOSED" => "DhanHQ::Constants::OrderStatus::CLOSED",
          "TRIGGERED" => "DhanHQ::Constants::OrderStatus::TRIGGERED",
          "REJECTED" => "DhanHQ::Constants::OrderStatus::REJECTED",
          "CANCELLED" => "DhanHQ::Constants::OrderStatus::CANCELLED",
          "PART_TRADED" => "DhanHQ::Constants::OrderStatus::PART_TRADED",
          "TRADED" => "DhanHQ::Constants::OrderStatus::TRADED",
          "EXPIRED" => "DhanHQ::Constants::OrderStatus::EXPIRED",
          "PRE_OPEN" => "DhanHQ::Constants::AmoTime::PRE_OPEN",
          "OPEN" => "DhanHQ::Constants::AmoTime::OPEN",
          "OPEN_30" => "DhanHQ::Constants::AmoTime::OPEN_30",
          "OPEN_60" => "DhanHQ::Constants::AmoTime::OPEN_60",
          "INDEX" => "DhanHQ::Constants::InstrumentType::INDEX",
          "FUTIDX" => "DhanHQ::Constants::InstrumentType::FUTIDX",
          "OPTIDX" => "DhanHQ::Constants::InstrumentType::OPTIDX",
          "EQUITY" => "DhanHQ::Constants::InstrumentType::EQUITY",
          "FUTSTK" => "DhanHQ::Constants::InstrumentType::FUTSTK",
          "OPTSTK" => "DhanHQ::Constants::InstrumentType::OPTSTK",
          "FUTCOM" => "DhanHQ::Constants::InstrumentType::FUTCOM",
          "OPTFUT" => "DhanHQ::Constants::InstrumentType::OPTFUT",
          "FUTCUR" => "DhanHQ::Constants::InstrumentType::FUTCUR",
          "OPTCUR" => "DhanHQ::Constants::InstrumentType::OPTCUR",
          "CALL" => "DhanHQ::Constants::OptionType::CALL",
          "PUT" => "DhanHQ::Constants::OptionType::PUT",
          "ENTRY_LEG" => "DhanHQ::Constants::LegName::ENTRY_LEG",
          "TARGET_LEG" => "DhanHQ::Constants::LegName::TARGET_LEG",
          "STOP_LOSS_LEG" => "DhanHQ::Constants::LegName::STOP_LOSS_LEG",
          "SINGLE" => "DhanHQ::Constants::OrderFlag::SINGLE",
          "OCO" => "DhanHQ::Constants::OrderFlag::OCO",
          "LONG" => "DhanHQ::Constants::PositionType::LONG",
          "SHORT" => "DhanHQ::Constants::PositionType::SHORT",
          "TECHNICAL_WITH_VALUE" => "DhanHQ::Constants::ComparisonType::TECHNICAL_WITH_VALUE",
          "TECHNICAL_WITH_INDICATOR" => "DhanHQ::Constants::ComparisonType::TECHNICAL_WITH_INDICATOR",
          "TECHNICAL_WITH_CLOSE" => "DhanHQ::Constants::ComparisonType::TECHNICAL_WITH_CLOSE",
          "PRICE_WITH_VALUE" => "DhanHQ::Constants::ComparisonType::PRICE_WITH_VALUE",
          "EMA_200" => "DhanHQ::Constants::IndicatorName::EMA_200",
          "BB_UPPER" => "DhanHQ::Constants::IndicatorName::BB_UPPER",
          "BB_LOWER" => "DhanHQ::Constants::IndicatorName::BB_LOWER",
          "RSI_14" => "DhanHQ::Constants::IndicatorName::RSI_14",
          "ATR_14" => "DhanHQ::Constants::IndicatorName::ATR_14",
          "STOCHASTIC" => "DhanHQ::Constants::IndicatorName::STOCHASTIC",
          "STOCHRSI_14" => "DhanHQ::Constants::IndicatorName::STOCHRSI_14",
          "MACD_26" => "DhanHQ::Constants::IndicatorName::MACD_26",
          "MACD_12" => "DhanHQ::Constants::IndicatorName::MACD_12",
          "MACD_HIST" => "DhanHQ::Constants::IndicatorName::MACD_HIST",
          "SMA_5" => "DhanHQ::Constants::IndicatorName::SMA_5",
          "SMA_10" => "DhanHQ::Constants::IndicatorName::SMA_10",
          "SMA_20" => "DhanHQ::Constants::IndicatorName::SMA_20",
          "SMA_50" => "DhanHQ::Constants::IndicatorName::SMA_50",
          "SMA_100" => "DhanHQ::Constants::IndicatorName::SMA_100",
          "SMA_200" => "DhanHQ::Constants::IndicatorName::SMA_200",
          "EMA_5" => "DhanHQ::Constants::IndicatorName::EMA_5",
          "EMA_10" => "DhanHQ::Constants::IndicatorName::EMA_10",
          "EMA_20" => "DhanHQ::Constants::IndicatorName::EMA_20",
          "EMA_50" => "DhanHQ::Constants::IndicatorName::EMA_50",
          "EMA_100" => "DhanHQ::Constants::IndicatorName::EMA_100",
          "GREATER_THAN_EQUAL" => "DhanHQ::Constants::Operator::GREATER_THAN_EQUAL",
          "LESS_THAN_EQUAL" => "DhanHQ::Constants::Operator::LESS_THAN_EQUAL",
          "EQUAL" => "DhanHQ::Constants::Operator::EQUAL",
          "NOT_EQUAL" => "DhanHQ::Constants::Operator::NOT_EQUAL",
          "CROSSING_UP" => "DhanHQ::Constants::Operator::CROSSING_UP",
          "CROSSING_DOWN" => "DhanHQ::Constants::Operator::CROSSING_DOWN",
          "CROSSING_ANY_SIDE" => "DhanHQ::Constants::Operator::CROSSING_ANY_SIDE",
          "GREATER_THAN" => "DhanHQ::Constants::Operator::GREATER_THAN",
          "LESS_THAN" => "DhanHQ::Constants::Operator::LESS_THAN",
          "ACTIVE" => "DhanHQ::Constants::TriggerStatus::ACTIVE",
          "IDX_I" => "DhanHQ::Constants::ExchangeSegment::IDX_I",
          "NSE_EQ" => "DhanHQ::Constants::ExchangeSegment::NSE_EQ",
          "NSE_FNO" => "DhanHQ::Constants::ExchangeSegment::NSE_FNO",
          "NSE_CURRENCY" => "DhanHQ::Constants::ExchangeSegment::NSE_CURRENCY",
          "BSE_EQ" => "DhanHQ::Constants::ExchangeSegment::BSE_EQ",
          "MCX_COMM" => "DhanHQ::Constants::ExchangeSegment::MCX_COMM",
          "BSE_CURRENCY" => "DhanHQ::Constants::ExchangeSegment::BSE_CURRENCY",
          "BSE_FNO" => "DhanHQ::Constants::ExchangeSegment::BSE_FNO",
          "DH-910" => "DhanHQ::Constants::TradingErrorCode::OTHERS",
          "DH-901" => "DhanHQ::Constants::TradingErrorCode::INVALID_AUTHENTICATION",
          "DH-902" => "DhanHQ::Constants::TradingErrorCode::INVALID_ACCESS",
          "DH-903" => "DhanHQ::Constants::TradingErrorCode::USER_ACCOUNT",
          "DH-904" => "DhanHQ::Constants::TradingErrorCode::RATE_LIMIT",
          "DH-905" => "DhanHQ::Constants::TradingErrorCode::INPUT_EXCEPTION",
          "DH-906" => "DhanHQ::Constants::TradingErrorCode::ORDER_ERROR",
          "DH-907" => "DhanHQ::Constants::TradingErrorCode::DATA_ERROR",
          "DH-908" => "DhanHQ::Constants::TradingErrorCode::INTERNAL_SERVER_ERROR",
          "DH-909" => "DhanHQ::Constants::TradingErrorCode::NETWORK_ERROR",
          "CNC" => "DhanHQ::Constants::ProductType::CNC",
          "INTRADAY" => "DhanHQ::Constants::ProductType::INTRADAY",
          "MARGIN" => "DhanHQ::Constants::ProductType::MARGIN",
          "MTF" => "DhanHQ::Constants::ProductType::MTF",
          "CO" => "DhanHQ::Constants::ProductType::CO",
          "BO" => "DhanHQ::Constants::ProductType::BO"
        }.freeze

        def on_str(node)
          value = node.value
          return unless CONSTANTS_MAP.key?(value)

          parent = node.parent
          return unless parent

          # Skip hash keys
          return if parent.pair_type? && parent.key == node

          # Skip typical ignored methods
          return if parent.send_type? && %i[require require_relative puts print warn raise fail class_eval instance_eval].include?(parent.method_name)

          # Skip error messages or descriptions
          return if value.include?(" ") || value.length < 2

          in_percent_array = parent.array_type? && parent.loc.begin&.source&.start_with?("%w", "%W", "%i", "%I")
          return if in_percent_array

          constant_path = CONSTANTS_MAP[value]

          add_offense(node, message: format(MSG, constant: constant_path, string: value)) do |corrector|
            corrector.replace(node, constant_path)
          end
        end
      end
    end
  end
end
