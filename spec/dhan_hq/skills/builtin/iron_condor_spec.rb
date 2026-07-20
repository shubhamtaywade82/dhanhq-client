# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::IronCondor do
  let(:chain) do
    build_option_chain([
                         { strike: 24_100, ce_id: "CE_24100", ce_price: 450.0, pe_id: "PE_24100", pe_price: 20.0 },
                         { strike: 24_300, ce_id: "CE_24300", ce_price: 300.0, pe_id: "PE_24300", pe_price: 50.0 },
                         { strike: 24_500, ce_id: "CE_24500", ce_price: 180.0, pe_id: "PE_24500", pe_price: 100.0 },
                         { strike: 24_700, ce_id: "CE_24700", ce_price: 90.0, pe_id: "PE_24700", pe_price: 190.0 },
                         { strike: 24_900, ce_id: "CE_24900", ce_price: 40.0, pe_id: "PE_24900", pe_price: 320.0 }
                       ])
  end

  let(:instrument) do
    # rubocop:disable RSpec/VerifiedDoubles
    double("instrument",
           ltp: 24_500.0,
           option_chain: chain)
    # rubocop:enable RSpec/VerifiedDoubles
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

    it "has defaults for quantity, wing_width, max_loss" do
      params = described_class.params
      expect(params[:quantity][:default]).to eq(50)
      expect(params[:wing_width][:default]).to eq(200)
      expect(params[:max_loss][:default]).to eq(5000)
    end
  end

  describe "#call" do
    it "selects 4 legs for iron condor" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:legs].length).to eq(4)
    end

    it "has sell CE, buy CE, sell PE, buy PE actions" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      actions = result[:legs].map { |l| l[:action] }
      expect(actions).to eq(%w[SELL BUY SELL BUY])
    end

    it "selects correct option types" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      types = result[:legs].map { |l| l[:option_type] }
      expect(types).to eq(%w[CE CE PE PE])
    end

    # rubocop:disable RSpec/MultipleExpectations
    it "builds intent with all required fields" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("IRON_CONDOR")
      expect(intent[:symbol]).to eq("NIFTY")
      expect(intent[:expiry]).to eq("2026-01-30")
      expect(intent[:quantity]).to eq(50)
      expect(intent[:legs].length).to eq(4)
      expect(intent[:note]).to include("Await human confirmation")
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "raises when chain has insufficient strikes" do
      allow(instrument).to receive(:option_chain).and_return(
        build_option_chain([{ strike: 24_500, ce_id: "CE_24500", ce_price: 180.0, pe_id: "PE_24500", pe_price: 100.0 }])
      )

      expect do
        described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      end.to raise_error(ArgumentError, /insufficient strikes/)
    end
  end
end
