# frozen_string_literal: true

module FakeInstrument
  DEFAULTS = {
    symbol: "NIFTY",
    symbol_name: "NIFTY",
    display_name: "NIFTY 50",
    underlying_symbol: "NIFTY",
    exchange_segment: "IDX_I",
    segment: "I",
    instrument: "INDEX",
    instrument_type: "INDEX",
    expiry_flag: "Y",
    security_id: "12345",
    isin: "IN0000000001",
    buy_sell_indicator: "A",
    bracket_flag: "Y",
    cover_flag: "Y",
    asm_gsm_flag: "N",
    asm_gsm_category: nil,
    mtf_leverage: 5,
    buy_co_min_margin_per: 20,
    sell_co_min_margin_per: 20
  }.freeze

  def self.build(overrides = {})
    Struct.new(*DEFAULTS.keys).new(**DEFAULTS, **overrides)
  end
end
