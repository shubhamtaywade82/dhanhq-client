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
  end
end
