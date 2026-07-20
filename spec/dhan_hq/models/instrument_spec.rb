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

  describe ".find" do
    let(:csv) do
      <<~CSV
        EXCH_ID,SEGMENT,SECURITY_ID,ISIN,INSTRUMENT,UNDERLYING_SECURITY_ID,UNDERLYING_SYMBOL,SYMBOL_NAME,DISPLAY_NAME,INSTRUMENT_TYPE,SERIES,LOT_SIZE,SM_EXPIRY_DATE,STRIKE_PRICE,OPTION_TYPE,TICK_SIZE,EXPIRY_FLAG,BRACKET_FLAG,COVER_FLAG,ASM_GSM_FLAG,ASM_GSM_CATEGORY,BUY_SELL_INDICATOR,BUY_CO_MIN_MARGIN_PER,SELL_CO_MIN_MARGIN_PER,BUY_CO_SL_RANGE_MAX_PERC,SELL_CO_SL_RANGE_MAX_PERC,BUY_CO_SL_RANGE_MIN_PERC,SELL_CO_SL_RANGE_MIN_PERC,BUY_BO_MIN_MARGIN_PER,SELL_BO_MIN_MARGIN_PER,BUY_BO_SL_RANGE_MAX_PERC,SELL_BO_SL_RANGE_MAX_PERC,BUY_BO_SL_RANGE_MIN_PERC,SELL_BO_SL_MIN_RANGE,BUY_BO_PROFIT_RANGE_MAX_PERC,SELL_BO_PROFIT_RANGE_MAX_PERC,BUY_BO_PROFIT_RANGE_MIN_PERC,SELL_BO_PROFIT_RANGE_MIN_PERC,MTF_LEVERAGE
        NSE,E,2885,INE002A01018,EQUITY,,RELIANCE,RELIANCE,RELIANCE INDUSTRIES,EQUITY,EQ,1.0,,,,0.05,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        NSE,E,1333,INE040A01034,EQUITY,,HDFCBANK,HDFCBANK,HDFC BANK,EQUITY,EQ,1.0,,,,0.05,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        NSE,I,13,,INDEX,,,NIFTY,NIFTY 50,INDEX,,,,,,,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
      CSV
    end

    before do
      allow(resource_double).to receive(:by_segment).with("NSE_EQ").and_return(csv)
      allow(resource_double).to receive(:by_segment).with("IDX_I").and_return(csv)
    end

    it "finds an equity by underlying_symbol with exact match" do
      instrument = described_class.find("NSE_EQ", "RELIANCE")

      expect(instrument.security_id).to eq("2885")
      expect(instrument.display_name).to eq("RELIANCE INDUSTRIES")
    end

    it "finds an index by symbol_name" do
      instrument = described_class.find("IDX_I", "NIFTY")

      expect(instrument.security_id).to eq("13")
    end

    it "matches case-insensitively by default" do
      instrument = described_class.find("NSE_EQ", "reliance")

      expect(instrument.security_id).to eq("2885")
    end

    it "returns nil when nothing matches" do
      expect(described_class.find("NSE_EQ", "NONEXISTENT")).to be_nil
    end

    it "only builds one Instrument instance for the match, not the whole segment" do
      allow(described_class).to receive(:new).and_call_original

      described_class.find("NSE_EQ", "RELIANCE")

      expect(described_class).to have_received(:new).once
    end
  end

  describe ".find_by_security_id" do
    let(:csv) do
      <<~CSV
        EXCH_ID,SEGMENT,SECURITY_ID,ISIN,INSTRUMENT,UNDERLYING_SECURITY_ID,UNDERLYING_SYMBOL,SYMBOL_NAME,DISPLAY_NAME,INSTRUMENT_TYPE,SERIES,LOT_SIZE,SM_EXPIRY_DATE,STRIKE_PRICE,OPTION_TYPE,TICK_SIZE,EXPIRY_FLAG,BRACKET_FLAG,COVER_FLAG,ASM_GSM_FLAG,ASM_GSM_CATEGORY,BUY_SELL_INDICATOR,BUY_CO_MIN_MARGIN_PER,SELL_CO_MIN_MARGIN_PER,BUY_CO_SL_RANGE_MAX_PERC,SELL_CO_SL_RANGE_MAX_PERC,BUY_CO_SL_RANGE_MIN_PERC,SELL_CO_SL_RANGE_MIN_PERC,BUY_BO_MIN_MARGIN_PER,SELL_BO_MIN_MARGIN_PER,BUY_BO_SL_RANGE_MAX_PERC,SELL_BO_SL_RANGE_MAX_PERC,BUY_BO_SL_RANGE_MIN_PERC,SELL_BO_SL_MIN_RANGE,BUY_BO_PROFIT_RANGE_MAX_PERC,SELL_BO_PROFIT_RANGE_MAX_PERC,BUY_BO_PROFIT_RANGE_MIN_PERC,SELL_BO_PROFIT_RANGE_MIN_PERC,MTF_LEVERAGE
        NSE,E,1333,INE040A01034,EQUITY,,,,HDFCBANK,EQUITY,EQ,1.0,,,,0.05,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        NSE,E,2885,INE002A01018,EQUITY,,,,RELIANCE,EQUITY,EQ,1.0,,,,0.05,NA,N,N,N,NA,A,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
      CSV
    end

    before do
      allow(resource_double).to receive(:by_segment).with("NSE_EQ").and_return(csv)
    end

    it "returns the instrument matching the security id within the segment" do
      instrument = described_class.find_by_security_id("NSE_EQ", "2885")

      expect(instrument.security_id).to eq("2885")
      expect(instrument.display_name).to eq("RELIANCE")
    end

    it "coerces integer security ids for comparison" do
      instrument = described_class.find_by_security_id("NSE_EQ", 1333)

      expect(instrument.security_id).to eq("1333")
    end

    it "returns nil when no instrument matches" do
      expect(described_class.find_by_security_id("NSE_EQ", "999999")).to be_nil
    end
  end
end
