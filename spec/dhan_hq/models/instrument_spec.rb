# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Instrument do
  let(:resource_double) { instance_double(DhanHQ::Resources::Instruments) }

  before do
    described_class.instance_variable_set(:@resource, nil)
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".by_segment" do
    it "validates segment and parses CSV into models" do
      csv = <<~CSV
        EXCH_ID,SEGMENT,SECURITY_ID,ISIN,INSTRUMENT,UNDERLYING_SECURITY_ID,UNDERLYING_SYMBOL,SYMBOL_NAME,DISPLAY_NAME,INSTRUMENT_TYPE,SERIES,LOT_SIZE,SM_EXPIRY_DATE,STRIKE_PRICE,OPTION_TYPE,TICK_SIZE,EXPIRY_FLAG,BRACKET_FLAG,COVER_FLAG,ASM_GSM_FLAG,ASM_GSM_CATEGORY,BUY_SELL_INDICATOR,BUY_CO_MIN_MARGIN_PER,SELL_CO_MIN_MARGIN_PER,BUY_CO_SL_RANGE_MAX_PERC,SELL_CO_SL_RANGE_MAX_PERC,BUY_CO_SL_RANGE_MIN_PERC,SELL_CO_SL_RANGE_MIN_PERC,BUY_BO_MIN_MARGIN_PER,SELL_BO_MIN_MARGIN_PER,BUY_BO_SL_RANGE_MAX_PERC,SELL_BO_SL_RANGE_MAX_PERC,BUY_BO_SL_RANGE_MIN_PERC,SELL_BO_SL_MIN_RANGE,BUY_BO_PROFIT_RANGE_MAX_PERC,SELL_BO_PROFIT_RANGE_MAX_PERC,BUY_BO_PROFIT_RANGE_MIN_PERC,SELL_BO_PROFIT_RANGE_MIN_PERC,MTF_LEVERAGE
        NSE,E,1333,INE040A01034,EQUITY,,,,HDFCBANK,EQUITY,EQ,1.0,,,,0.05,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
      CSV
      allow(resource_double).to receive(:by_segment).with("NSE_EQ").and_return(csv)

      list = described_class.by_segment("NSE_EQ")
      expect(list).to all(be_a(described_class))
      expect(list.first.security_id).to eq("1333")
      expect(list.first.exchange_segment).to eq("NSE_EQ")
      expect(list.first.instrument).to eq("EQUITY")
    end

    it "returns [] on blank or non-string response" do
      allow(resource_double).to receive(:by_segment).and_return("")
      expect(described_class.by_segment("NSE_EQ")).to eq([])
    end
  end
end
