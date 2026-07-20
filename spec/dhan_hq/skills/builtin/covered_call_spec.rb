# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Skills::Builtin::CoveredCall do
  let(:chain) do
    [
      { strike: 2400, option_type: "CE", security_id: "CE01", last_price: 50.0 },
      { strike: 2450, option_type: "CE", security_id: "CE02", last_price: 30.0 },
      { strike: 2500, option_type: "CE", security_id: "CE03", last_price: 15.0 },
      { strike: 2550, option_type: "CE", security_id: "CE04", last_price: 8.0 }
    ]
  end

  let(:instrument) do
    double("instrument",
           ltp: { ltp: 2450.0 },
           security_id: "EQ001",
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
      expect(params[:quantity][:default]).to eq(100)
      expect(params[:strike_offset][:default]).to eq(2.0)
    end
  end

  describe "#call" do
    it "finds instrument on NSE_EQ exchange" do
      described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      expect(DhanHQ::Models::Instrument).to have_received(:find).with("NSE_EQ", "RELIANCE")
    end

    it "selects OTM call strike above spot" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      call_leg = result[:intent][:legs].find { |l| l[:option_type] == "CE" }
      expect(call_leg[:strike]).to be > 2450
    end

    # rubocop:disable RSpec/MultipleExpectations
    it "builds intent with equity and option legs" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("COVERED_CALL")
      expect(intent[:legs].length).to eq(2)
      expect(intent[:legs][0][:action]).to eq("BUY")
      expect(intent[:legs][0][:instrument_type]).to eq("EQUITY")
      expect(intent[:legs][1][:action]).to eq("SELL")
      expect(intent[:legs][1][:option_type]).to eq("CE")
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "includes confirmation note" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      expect(result[:intent][:note]).to include("Await human confirmation")
    end

    it "raises on missing symbol" do
      expect { described_class.new.call(expiry: "2026-01-30") }.to raise_error(ArgumentError, /symbol/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
