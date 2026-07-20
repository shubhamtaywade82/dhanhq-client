# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Skills::Builtin::Straddle do
  let(:chain) do
    build_option_chain([
                         { strike: 24_400, ce_id: "CE_24400", ce_price: 150.0, pe_id: "PE_24400", pe_price: 50.0 },
                         { strike: 24_500, ce_id: "CE_24500", ce_price: 100.0, pe_id: "PE_24500", pe_price: 80.0 },
                         { strike: 24_600, ce_id: "CE_24600", ce_price: 60.0, pe_id: "PE_24600", pe_price: 120.0 }
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
      expect(params[:quantity][:default]).to eq(25)
      expect(params[:stop_loss][:default]).to eq(300)
      expect(params[:target][:default]).to eq(600)
    end
  end

  describe "#call" do
    it "selects 2 ATM legs for straddle" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:intent][:legs].length).to eq(2)
    end

    it "selects CE and PE at the same strike" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      legs = result[:intent][:legs]
      expect(legs[0][:option_type]).to eq("CE")
      expect(legs[1][:option_type]).to eq("PE")
      expect(legs[0][:strike]).to eq(legs[1][:strike])
    end

    it "both legs are BUY" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      actions = result[:intent][:legs].map { |l| l[:action] }
      expect(actions).to eq(%w[BUY BUY])
    end

    it "calculates total premium and break-even points" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:total_premium]).to eq(180.0)
      expect(intent[:break_even_upside]).to eq(24_680.0)
      expect(intent[:break_even_downside]).to eq(24_320.0)
    end

    # rubocop:disable RSpec/MultipleExpectations
    it "builds intent with correct fields" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("STRADDLE")
      expect(intent[:symbol]).to eq("NIFTY")
      expect(intent[:expiry]).to eq("2026-01-30")
      expect(intent[:quantity]).to eq(25)
      expect(intent[:stop_loss]).to eq(300)
      expect(intent[:target]).to eq(600)
      expect(intent[:note]).to include("Await human confirmation")
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "raises on missing symbol" do
      expect { described_class.new.call(expiry: "2026-01-30") }.to raise_error(ArgumentError, /symbol/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
