# frozen_string_literal: true

require_relative "errors"

module DhanHQ
  # Enumerations and helper lookups used across the REST and WebSocket clients.
  module Constants
    # Exchange segments for different markets and instruments.
    module ExchangeSegment
      IDX_I = "IDX_I"
      NSE_EQ = "NSE_EQ"
      NSE_FNO = "NSE_FNO"
      NSE_CURRENCY = "NSE_CURRENCY"
      BSE_EQ = "BSE_EQ"
      MCX_COMM = "MCX_COMM"
      BSE_CURRENCY = "BSE_CURRENCY"
      BSE_FNO = "BSE_FNO"

      ALL = [IDX_I, NSE_EQ, NSE_FNO, NSE_CURRENCY, BSE_EQ, MCX_COMM, BSE_CURRENCY, BSE_FNO].freeze
    end

    # Product types for order placement.
    module ProductType
      CNC = "CNC"
      INTRADAY = "INTRADAY"
      MARGIN = "MARGIN"
      MTF = "MTF"
      CO = "CO"
      BO = "BO"

      ALL = [CNC, INTRADAY, MARGIN, MTF, CO, BO].freeze
    end

    # Buy/Sell transaction types.
    module TransactionType
      BUY = "BUY"
      SELL = "SELL"

      ALL = [BUY, SELL].freeze
    end

    # Order types for placement and modification.
    module OrderType
      LIMIT = "LIMIT"
      MARKET = "MARKET"
      STOP_LOSS = "STOP_LOSS"
      STOP_LOSS_MARKET = "STOP_LOSS_MARKET"

      ALL = [LIMIT, MARKET, STOP_LOSS, STOP_LOSS_MARKET].freeze
    end

    # Order validity types.
    module Validity
      DAY = "DAY"
      IOC = "IOC"

      ALL = [DAY, IOC].freeze
    end

    # Order lifecycle status values.
    module OrderStatus
      TRANSIT = "TRANSIT"
      PENDING = "PENDING"
      CLOSED = "CLOSED"
      TRIGGERED = "TRIGGERED"
      REJECTED = "REJECTED"
      CANCELLED = "CANCELLED"
      PART_TRADED = "PART_TRADED"
      TRADED = "TRADED"
      EXPIRED = "EXPIRED"

      ALL = [TRANSIT, PENDING, CLOSED, TRIGGERED, REJECTED, CANCELLED, PART_TRADED, TRADED, EXPIRED].freeze
    end

    # AMO (after market order) timing options.
    module AmoTime
      PRE_OPEN = "PRE_OPEN"
      OPEN = "OPEN"
      OPEN_30 = "OPEN_30"
      OPEN_60 = "OPEN_60"

      ALL = [PRE_OPEN, OPEN, OPEN_30, OPEN_60].freeze
    end

    # Expiry codes for futures and options.
    module ExpiryCode
      CURRENT = 0
      NEXT = 1
      FAR = 2

      ALL = [CURRENT, NEXT, FAR].freeze
    end

    # Instrument types across exchanges.
    module InstrumentType
      INDEX = "INDEX"
      FUTIDX = "FUTIDX"
      OPTIDX = "OPTIDX"
      EQUITY = "EQUITY"
      FUTSTK = "FUTSTK"
      OPTSTK = "OPTSTK"
      FUTCOM = "FUTCOM"
      OPTFUT = "OPTFUT"
      FUTCUR = "FUTCUR"
      OPTCUR = "OPTCUR"

      ALL = [INDEX, FUTIDX, OPTIDX, EQUITY, FUTSTK, OPTSTK, FUTCOM, OPTFUT, FUTCUR, OPTCUR].freeze
    end

    # Backward-compatible alias kept for existing SDK usage.
    Instrument = InstrumentType

    # Option types for derivatives trading.
    module OptionType
      CALL = "CALL"
      PUT = "PUT"

      ALL = [CALL, PUT].freeze
    end

    # Leg names used in BO/CO/Super/Forever orders.
    module LegName
      ENTRY_LEG = "ENTRY_LEG"
      TARGET_LEG = "TARGET_LEG"
      STOP_LOSS_LEG = "STOP_LOSS_LEG"

      ALL = [ENTRY_LEG, TARGET_LEG, STOP_LOSS_LEG].freeze
    end

    # Order flags for Forever Orders.
    module OrderFlag
      SINGLE = "SINGLE"
      OCO = "OCO"

      ALL = [SINGLE, OCO].freeze
    end

    # Position types for position conversion.
    module PositionType
      LONG = "LONG"
      SHORT = "SHORT"

      ALL = [LONG, SHORT].freeze
    end

    # Feed request codes for Live Market Feed WebSocket.
    module FeedRequest
      CONNECT = 11
      DISCONNECT = 12
      SUBSCRIBE_TICKER = 15
      UNSUBSCRIBE_TICKER = 16
      SUBSCRIBE_QUOTE = 17
      UNSUBSCRIBE_QUOTE = 18
      SUBSCRIBE_FULL = 21
      UNSUBSCRIBE_FULL = 22
      SUBSCRIBE_DEPTH = 23
      UNSUBSCRIBE_DEPTH = 24

      ALL = [
        CONNECT,
        DISCONNECT,
        SUBSCRIBE_TICKER,
        UNSUBSCRIBE_TICKER,
        SUBSCRIBE_QUOTE,
        UNSUBSCRIBE_QUOTE,
        SUBSCRIBE_FULL,
        UNSUBSCRIBE_FULL,
        SUBSCRIBE_DEPTH,
        UNSUBSCRIBE_DEPTH
      ].freeze
    end

    # Feed response codes for Live Market Feed WebSocket.
    module FeedResponse
      INDEX_PACKET = 1
      TICKER_PACKET = 2
      QUOTE_PACKET = 4
      OI_PACKET = 5
      PREV_CLOSE_PACKET = 6
      MARKET_STATUS_PACKET = 7
      FULL_PACKET = 8
      FEED_DISCONNECT = 50

      ALL = [
        INDEX_PACKET,
        TICKER_PACKET,
        QUOTE_PACKET,
        OI_PACKET,
        PREV_CLOSE_PACKET,
        MARKET_STATUS_PACKET,
        FULL_PACKET,
        FEED_DISCONNECT
      ].freeze
    end

    # Comparison types for conditional trigger alerts.
    module ComparisonType
      TECHNICAL_WITH_VALUE = "TECHNICAL_WITH_VALUE"
      TECHNICAL_WITH_INDICATOR = "TECHNICAL_WITH_INDICATOR"
      TECHNICAL_WITH_CLOSE = "TECHNICAL_WITH_CLOSE"
      PRICE_WITH_VALUE = "PRICE_WITH_VALUE"

      ALL = [
        TECHNICAL_WITH_VALUE,
        TECHNICAL_WITH_INDICATOR,
        TECHNICAL_WITH_CLOSE,
        PRICE_WITH_VALUE
      ].freeze
    end

    # Technical indicators for conditional triggers.
    module IndicatorName
      SMA_5 = "SMA_5"
      SMA_10 = "SMA_10"
      SMA_20 = "SMA_20"
      SMA_50 = "SMA_50"
      SMA_100 = "SMA_100"
      SMA_200 = "SMA_200"

      EMA_5 = "EMA_5"
      EMA_10 = "EMA_10"
      EMA_20 = "EMA_20"
      EMA_50 = "EMA_50"
      EMA_100 = "EMA_100"
      EMA_200 = "EMA_200"

      BB_UPPER = "BB_UPPER"
      BB_LOWER = "BB_LOWER"
      RSI_14 = "RSI_14"
      ATR_14 = "ATR_14"
      STOCHASTIC = "STOCHASTIC"
      STOCHRSI_14 = "STOCHRSI_14"
      MACD_26 = "MACD_26"
      MACD_12 = "MACD_12"
      MACD_HIST = "MACD_HIST"

      ALL = [
        SMA_5,
        SMA_10,
        SMA_20,
        SMA_50,
        SMA_100,
        SMA_200,
        EMA_5,
        EMA_10,
        EMA_20,
        EMA_50,
        EMA_100,
        EMA_200,
        BB_UPPER,
        BB_LOWER,
        RSI_14,
        ATR_14,
        STOCHASTIC,
        STOCHRSI_14,
        MACD_26,
        MACD_12,
        MACD_HIST
      ].freeze
    end

    # Operators for conditional trigger comparisons.
    module Operator
      CROSSING_UP = "CROSSING_UP"
      CROSSING_DOWN = "CROSSING_DOWN"
      CROSSING_ANY_SIDE = "CROSSING_ANY_SIDE"
      GREATER_THAN = "GREATER_THAN"
      LESS_THAN = "LESS_THAN"
      GREATER_THAN_EQUAL = "GREATER_THAN_EQUAL"
      LESS_THAN_EQUAL = "LESS_THAN_EQUAL"
      EQUAL = "EQUAL"
      NOT_EQUAL = "NOT_EQUAL"

      ALL = [
        CROSSING_UP,
        CROSSING_DOWN,
        CROSSING_ANY_SIDE,
        GREATER_THAN,
        LESS_THAN,
        GREATER_THAN_EQUAL,
        LESS_THAN_EQUAL,
        EQUAL,
        NOT_EQUAL
      ].freeze
    end

    # Status values for conditional trigger alerts.
    module TriggerStatus
      ACTIVE = "ACTIVE"
      TRIGGERED = "TRIGGERED"
      EXPIRED = "EXPIRED"
      CANCELLED = "CANCELLED"

      ALL = [ACTIVE, TRIGGERED, EXPIRED, CANCELLED].freeze
    end

    # Trading API error codes (DH-900 series).
    module TradingErrorCode
      INVALID_AUTHENTICATION = "DH-901"
      INVALID_ACCESS = "DH-902"
      USER_ACCOUNT = "DH-903"
      RATE_LIMIT = "DH-904"
      INPUT_EXCEPTION = "DH-905"
      ORDER_ERROR = "DH-906"
      DATA_ERROR = "DH-907"
      INTERNAL_SERVER_ERROR = "DH-908"
      NETWORK_ERROR = "DH-909"
      OTHERS = "DH-910"

      ALL = [
        INVALID_AUTHENTICATION,
        INVALID_ACCESS,
        USER_ACCOUNT,
        RATE_LIMIT,
        INPUT_EXCEPTION,
        ORDER_ERROR,
        DATA_ERROR,
        INTERNAL_SERVER_ERROR,
        NETWORK_ERROR,
        OTHERS
      ].freeze
    end

    # Data API error codes (800 series).
    module DataErrorCode
      INTERNAL_SERVER_ERROR = 800
      INSTRUMENTS_LIMIT = 804
      TOO_MANY_REQUESTS = 805
      NOT_SUBSCRIBED = 806
      TOKEN_EXPIRED = 807
      AUTH_FAILED = 808
      INVALID_TOKEN = 809
      INVALID_CLIENT_ID = 810
      INVALID_EXPIRY_DATE = 811
      INVALID_DATE_FORMAT = 812
      INVALID_SECURITY_ID = 813
      INVALID_REQUEST = 814

      ALL = [
        INTERNAL_SERVER_ERROR,
        INSTRUMENTS_LIMIT,
        TOO_MANY_REQUESTS,
        NOT_SUBSCRIBED,
        TOKEN_EXPIRED,
        AUTH_FAILED,
        INVALID_TOKEN,
        INVALID_CLIENT_ID,
        INVALID_EXPIRY_DATE,
        INVALID_DATE_FORMAT,
        INVALID_SECURITY_ID,
        INVALID_REQUEST
      ].freeze
    end

    # Public rate limits published in DhanHQ API documentation.
    module RateLimit
      ORDER_API = { per_second: 10, per_minute: 250, per_hour: 1000, per_day: 7000 }.freeze
      DATA_API = { per_second: 5, per_day: 100_000 }.freeze
      QUOTE_API = { per_second: 1 }.freeze
      NON_TRADING_API = { per_second: 20 }.freeze
      ORDER_MODIFICATIONS_PER_ORDER = 25
    end

    # Backward-compatible arrays used across existing validations.
    TRANSACTION_TYPES = TransactionType::ALL
    EXCHANGE_SEGMENTS = ExchangeSegment::ALL
    INSTRUMENTS = InstrumentType::ALL
    PRODUCT_TYPES = ProductType::ALL
    ORDER_TYPES = OrderType::ALL
    VALIDITY_TYPES = Validity::ALL
    AMO_TIMINGS = AmoTime::ALL
    ORDER_STATUSES = OrderStatus::ALL

    # Exchange aliases used when building subscription payloads.
    NSE = ExchangeSegment::NSE_EQ
    BSE = ExchangeSegment::BSE_EQ
    CUR = ExchangeSegment::NSE_CURRENCY
    MCX = ExchangeSegment::MCX_COMM
    FNO = ExchangeSegment::NSE_FNO
    NSE_FNO = ExchangeSegment::NSE_FNO
    BSE_FNO = ExchangeSegment::BSE_FNO
    INDEX = ExchangeSegment::IDX_I

    OPTION_SEGMENTS = [NSE, BSE, CUR, MCX, FNO, NSE_FNO, BSE_FNO, INDEX].freeze

    # Canonical labels kept for compatibility with previous SDK versions.
    BUY = TransactionType::BUY
    SELL = TransactionType::SELL

    CNC = ProductType::CNC
    INTRA = ProductType::INTRADAY
    MARGIN = ProductType::MARGIN
    CO = ProductType::CO
    BO = ProductType::BO
    MTF = ProductType::MTF

    LIMIT = OrderType::LIMIT
    MARKET = OrderType::MARKET
    SL = OrderType::STOP_LOSS
    SLM = OrderType::STOP_LOSS_MARKET

    DAY = Validity::DAY
    IOC = Validity::IOC

    # Download URL for the compact instrument master CSV.
    COMPACT_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master.csv"
    # Download URL for the detailed instrument master CSV.
    DETAILED_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master-detailed.csv"

    # API route prefixes that require a `client-id` header in addition to the access token.
    DATA_API_PREFIXES = [
      "/v2/marketfeed/",
      "/v2/optionchain",
      "/v2/instrument/"
    ].freeze

    # Mapping of exchange and segment combinations to canonical exchange segment names.
    SEGMENT_MAP = {
      %w[NSE E] => ExchangeSegment::NSE_EQ,
      %w[BSE E] => ExchangeSegment::BSE_EQ,
      %w[NSE D] => ExchangeSegment::NSE_FNO,
      %w[BSE D] => ExchangeSegment::BSE_FNO,
      %w[NSE C] => ExchangeSegment::NSE_CURRENCY,
      %w[BSE C] => ExchangeSegment::BSE_CURRENCY,
      %w[MCX M] => ExchangeSegment::MCX_COMM,
      %w[NSE I] => ExchangeSegment::IDX_I,
      %w[BSE I] => ExchangeSegment::IDX_I
    }.freeze

    # Mapping of DhanHQ error codes to SDK error classes for consistent exception handling.
    DHAN_ERROR_MAPPING = {
      TradingErrorCode::INVALID_AUTHENTICATION => DhanHQ::InvalidAuthenticationError,
      TradingErrorCode::INVALID_ACCESS => DhanHQ::InvalidAccessError,
      TradingErrorCode::USER_ACCOUNT => DhanHQ::UserAccountError,
      TradingErrorCode::RATE_LIMIT => DhanHQ::RateLimitError,
      TradingErrorCode::INPUT_EXCEPTION => DhanHQ::InputExceptionError,
      TradingErrorCode::ORDER_ERROR => DhanHQ::OrderError,
      TradingErrorCode::DATA_ERROR => DhanHQ::DataError,
      TradingErrorCode::INTERNAL_SERVER_ERROR => DhanHQ::InternalServerError,
      "DH-1111" => DhanHQ::NoHoldingsError,
      TradingErrorCode::NETWORK_ERROR => DhanHQ::NetworkError,
      TradingErrorCode::OTHERS => DhanHQ::OtherError,
      DataErrorCode::INTERNAL_SERVER_ERROR.to_s => DhanHQ::InternalServerError,
      DataErrorCode::INSTRUMENTS_LIMIT.to_s => DhanHQ::Error,
      DataErrorCode::TOO_MANY_REQUESTS.to_s => DhanHQ::RateLimitError,
      DataErrorCode::NOT_SUBSCRIBED.to_s => DhanHQ::DataError,
      DataErrorCode::TOKEN_EXPIRED.to_s => DhanHQ::TokenExpiredError,
      DataErrorCode::AUTH_FAILED.to_s => DhanHQ::AuthenticationFailedError,
      DataErrorCode::INVALID_TOKEN.to_s => DhanHQ::InvalidTokenError,
      DataErrorCode::INVALID_CLIENT_ID.to_s => DhanHQ::InvalidClientIDError,
      DataErrorCode::INVALID_EXPIRY_DATE.to_s => DhanHQ::InvalidRequestError,
      DataErrorCode::INVALID_DATE_FORMAT.to_s => DhanHQ::InvalidRequestError,
      DataErrorCode::INVALID_SECURITY_ID.to_s => DhanHQ::InvalidRequestError,
      DataErrorCode::INVALID_REQUEST.to_s => DhanHQ::InvalidRequestError
    }.freeze

    # Validate if a value belongs to a constants module that exposes ALL.
    def self.valid?(module_name, value)
      mod = resolve_module(module_name)
      mod.const_defined?(:ALL) && mod::ALL.include?(value)
    rescue NameError
      false
    end

    # Get all values for a constants module that exposes ALL.
    def self.all_for(module_name)
      mod = resolve_module(module_name)
      return [] unless mod.const_defined?(:ALL)

      mod::ALL
    rescue NameError
      []
    end

    # Resolve symbols, strings, or direct modules under DhanHQ::Constants.
    def self.resolve_module(module_name)
      return module_name if module_name.is_a?(Module)

      const_get(module_name.to_s)
    end
    private_class_method :resolve_module
  end
end
