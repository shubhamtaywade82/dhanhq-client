# frozen_string_literal: true

module DhanHQ
  # Enumerations and helper lookups used across the REST and WebSocket clients.
  module Constants
    # Valid transaction directions accepted by order placement APIs.
    TRANSACTION_TYPES = %w[BUY SELL].freeze

    # Supported exchange segments for security lookups and subscription APIs.
    EXCHANGE_SEGMENTS = %w[
      NSE_EQ
      NSE_FNO
      NSE_CURRENCY
      BSE_EQ
      BSE_FNO
      BSE_CURRENCY
      MCX_COMM
      IDX_I
    ].freeze

    # Security instrument kinds returned in instrument master downloads.
    INSTRUMENTS = %w[
      INDEX
      FUTIDX
      OPTIDX
      EQUITY
      FUTSTK
      OPTSTK
      FUTCOM
      OPTFUT
      FUTCUR
      OPTCUR
    ].freeze

    # Product types that can be used while placing or modifying orders.
    PRODUCT_TYPES = %w[
      CNC
      INTRADAY
      MARGIN
      MTF
      CO
      BO
    ].freeze

    # Order execution types supported by the platform.
    ORDER_TYPES = %w[
      LIMIT
      MARKET
      STOP_LOSS
      STOP_LOSS_MARKET
    ].freeze

    # Order validity flags supported by the trading APIs.
    VALIDITY_TYPES = %w[DAY IOC].freeze

    # Permitted after-market order submission windows.
    AMO_TIMINGS = %w[
      OPEN
      OPEN_30
      OPEN_60
      PRE_OPEN
    ].freeze

    # Status values returned when querying order lifecycle events.
    ORDER_STATUSES = %w[
      TRANSIT
      PENDING
      REJECTED
      CANCELLED
      PART_TRADED
      TRADED
      EXPIRED
      MODIFIED
      TRIGGERED
    ].freeze

    # Exchange aliases used when building subscription payloads.
    NSE = "NSE_EQ"
    # Bombay Stock Exchange equities segment alias.
    BSE = "BSE_EQ"
    # Currency segment alias.
    CUR = "NSE_CURRENCY"
    # Multi Commodity Exchange segment alias.
    MCX = "MCX_COMM"
    # F&O segment alias.
    FNO = "NSE_FNO"
    # National Stock Exchange futures & options segment alias.
    NSE_FNO = "NSE_FNO"
    # Bombay Stock Exchange futures & options segment alias.
    BSE_FNO = "BSE_FNO"
    # Broad index segment alias.
    INDEX = "IDX_I"

    # Segments that support option instruments.
    OPTION_SEGMENTS = [NSE, BSE, CUR, MCX, FNO, NSE_FNO, BSE_FNO, INDEX].freeze

    # Canonical buy transaction label.
    BUY = "BUY"
    # Canonical sell transaction label.
    SELL = "SELL"

    # Cash-and-carry product identifier.
    CNC = "CNC"
    # Intraday margin product identifier.
    INTRA = "INTRADAY"
    # Carry-forward margin product identifier.
    MARGIN = "MARGIN"
    # Cover order product identifier.
    CO = "CO"
    # Bracket order product identifier.
    BO = "BO"
    # Margin trading funding identifier.
    MTF = "MTF"

    # Limit price order type.
    LIMIT = "LIMIT"
    # Market order type.
    MARKET = "MARKET"
    # Stop-loss limit order type.
    SL = "STOP_LOSS"
    # Stop-loss market order type.
    SLM = "STOP_LOSS_MARKET"

    # Good-for-day validity flag.
    DAY = "DAY"
    # Immediate-or-cancel validity flag.
    IOC = "IOC"

    # Download URL for the compact instrument master CSV.
    COMPACT_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master.csv"
    # Download URL for the detailed instrument master CSV.
    DETAILED_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master-detailed.csv"

    # API routes that require a `client-id` header in addition to the access token.
    DATA_API_PATHS = %w[
      /v2/marketfeed/ltp
      /v2/marketfeed/ohlc
      /v2/marketfeed/quote
      /v2/optionchain
      /v2/optionchain/expirylist
    ].freeze

    # Mapping of DhanHQ error codes to SDK error classes for consistent exception handling.
    DHAN_ERROR_MAPPING = {
      "DH-901" => DhanHQ::InvalidAuthenticationError,
      "DH-902" => DhanHQ::InvalidAccessError,
      "DH-903" => DhanHQ::UserAccountError,
      "DH-904" => DhanHQ::RateLimitError,
      "DH-905" => DhanHQ::InputExceptionError,
      "DH-906" => DhanHQ::OrderError,
      "DH-907" => DhanHQ::DataError,
      "DH-908" => DhanHQ::InternalServerError,
      "DH-1111" => DhanHQ::NoHoldingsError,
      "DH-909" => DhanHQ::NetworkError,
      "DH-910" => DhanHQ::OtherError,
      "800" => DhanHQ::InternalServerError,
      "804" => DhanHQ::Error, # Too many instruments
      "805" => DhanHQ::RateLimitError, # Too many requests
      "806" => DhanHQ::DataError, # Data API not subscribed
      "807" => DhanHQ::InvalidTokenError, # Token expired
      "808" => DhanHQ::AuthenticationFailedError, # Auth failed
      "809" => DhanHQ::InvalidTokenError, # Invalid token
      "810" => DhanHQ::InvalidClientIDError, # Invalid Client ID
      "811" => DhanHQ::InvalidRequestError,  # Invalid expiry date
      "812" => DhanHQ::InvalidRequestError,  # Invalid date format
      "813" => DhanHQ::InvalidRequestError,  # Invalid security ID
      "814" => DhanHQ::InvalidRequestError # Invalid request
    }.freeze
  end
end
