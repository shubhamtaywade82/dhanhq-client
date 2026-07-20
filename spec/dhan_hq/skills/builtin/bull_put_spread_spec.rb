# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Skills::Builtin::BullPutSpread do
  let(:chain) do
    build_option_chain([
                         { strike: 24_100, ce_id: "CE_24100", ce_price: 500.0, pe_id: "PE_24100", pe_price: 20.0 },
                         { strike: 24_200, ce_id: "CE_24200", ce_price: 420.0, pe_id: "PE_24200", pe_price: 35.0 },
                         { strike: 24_300, ce_id: "CE_24300", ce_price: 340.0, pe_id: "PE_24300", pe_price: 55.0 },
                         { strike: 24_400, ce_id: "CE_24400", ce_price: 260.0, pe_id: "PE_24400", pe_price: 85.0 },
                         { strike: 24_500, ce_id: "CE_24500", ce_price: 180.0, pe_id: "PE_24500", pe_price: 120.0 },
                         { strike: 24_600, ce_id: "CE_24600", ce_price: 130.0, pe_id: "PE_24600", pe_price: 220.0 },
                         { strike: 24_800, ce_id: "CE_24800", ce_price: 90.0, pe_id: "PE_24800", pe_price: 380.0 }
                       ])
  end

  let(:instrument) do
    double("instrument",
           ltp: 24_500.0,
           option_chain: chain)
  end

  before do
    allow(DhanHQ::Models::Instrument).to receive(:find).and_return(instrument)
  end

  describe "parameter definitions" do
    it "requires symbol and expiry" do
      params = described_class.params
      expect(params[:symbol][:required]).to be true
      expect(params[:expiry][:required]).to be true
    end

    it "has defaults" do
      params = described_class.params
      expect(params[:quantity][:default]).to eq(50)
      expect(params[:spread_width][:default]).to eq(200)
    end
  end

  describe "#call" do
    it "selects 2 PE legs for bull put spread" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:legs].length).to eq(2)
    end

    it "has sell PE and buy PE actions" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      actions = result[:legs].map { |l| l[:action] }
      expect(actions).to eq(%w[SELL BUY])
    end

    it "all legs are PE" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      types = result[:legs].map { |l| l[:option_type] }
      expect(types).to eq(%w[PE PE])
    end

    it "builds intent with correct fields" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("BULL_PUT_SPREAD")
      expect(intent[:symbol]).to eq("NIFTY")
      expect(intent[:expiry]).to eq("2026-01-30")
      expect(intent[:quantity]).to eq(50)
      expect(intent[:note]).to include("Await human confirmation")
    end

    it "raises when chain has insufficient strikes" do
      allow(instrument).to receive(:option_chain).and_return(
        build_option_chain([{ strike: 24_500, ce_id: "CE_24500", ce_price: 180.0, pe_id: "PE_24500", pe_price: 120.0 }])
      )

      expect do
        described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      end.to raise_error(ArgumentError, /insufficient strikes/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
