# frozen_string_literal: true

module DhanHQ
  module Constants
    TRANSACTION_TYPES = %w[BUY SELL].freeze

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

    PRODUCT_TYPES = %w[
      CNC
      INTRADAY
      MARGIN
      MTF
      CO
      BO
    ].freeze

    ORDER_TYPES = %w[
      LIMIT
      MARKET
      STOP_LOSS
      STOP_LOSS_MARKET
    ].freeze

    VALIDITY_TYPES = %w[DAY IOC].freeze

    AMO_TIMINGS = %w[
      OPEN
      OPEN_30
      OPEN_60
      PRE_OPEN
    ].freeze

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

    # Constants for Exchange Segment
    NSE = "NSE_EQ"
    BSE = "BSE_EQ"
    CUR = "NSE_CURRENCY"
    MCX = "MCX_COMM"
    FNO = "NSE_FNO"
    NSE_FNO = "NSE_FNO"
    BSE_FNO = "BSE_FNO"
    INDEX = "IDX_I"

    OPTION_SEGMENTS = [NSE, BSE, CUR, MCX, FNO, NSE_FNO, BSE_FNO, INDEX].freeze

    # Constants for Transaction Type
    BUY = "BUY"
    SELL = "SELL"

    # Constants for Product Type
    CNC = "CNC"
    INTRA = "INTRADAY"
    MARGIN = "MARGIN"
    CO = "CO"
    BO = "BO"
    MTF = "MTF"

    # Constants for Order Type
    LIMIT = "LIMIT"
    MARKET = "MARKET"
    SL = "STOP_LOSS"
    SLM = "STOP_LOSS_MARKET"

    # Constants for Validity
    DAY = "DAY"
    IOC = "IOC"

    # CSV URLs for Security ID List
    COMPACT_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master.csv"
    DETAILED_CSV_URL = "https://images.dhan.co/api-data/api-scrip-master-detailed.csv"

    # Paths that require `client-id` in headers
    DATA_API_PATHS = %w[
      /v2/marketfeed/ltp
      /v2/marketfeed/ohlc
      /v2/marketfeed/quote
      /v2/optionchain
      /v2/optionchain/expirylist
    ].freeze

    # DHANHQ API Error Mapping
    DHAN_ERROR_MAPPING = {
      "DH-901" => DhanHQ::InvalidAuthenticationError,
      "DH-902" => DhanHQ::InvalidAccessError,
      "DH-903" => DhanHQ::UserAccountError,
      "DH-904" => DhanHQ::RateLimitError,
      "DH-905" => DhanHQ::InputExceptionError,
      "DH-906" => DhanHQ::OrderError,
      "DH-907" => DhanHQ::DataError,
      "DH-908" => DhanHQ::InternalServerError,
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
