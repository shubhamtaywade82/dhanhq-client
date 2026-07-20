# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Skills::Builtin::ProtectivePut do
  let(:chain) do
    [
      { strike: 2300, option_type: "PE", security_id: "PE01", last_price: 10.0 },
      { strike: 2350, option_type: "PE", security_id: "PE02", last_price: 20.0 },
      { strike: 2400, option_type: "PE", security_id: "PE03", last_price: 35.0 },
      { strike: 2450, option_type: "CE", security_id: "CE01", last_price: 40.0 }
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
  end

  describe "#call" do
    it "finds instrument on NSE_EQ" do
      described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      expect(DhanHQ::Models::Instrument).to have_received(:find).with("NSE_EQ", "RELIANCE")
    end

    it "selects OTM put strike below spot" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      put_leg = result[:intent][:legs].find { |l| l[:option_type] == "PE" }
      expect(put_leg[:strike]).to be < 2450
    end

    it "builds intent with equity and put legs" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("PROTECTIVE_PUT")
      expect(intent[:legs].length).to eq(2)
      expect(intent[:legs][0][:instrument_type]).to eq("EQUITY")
      expect(intent[:legs][1][:option_type]).to eq("PE")
    end

    it "both legs are BUY" do
      result = described_class.new.call(symbol: "RELIANCE", expiry: "2026-01-30")
      actions = result[:intent][:legs].map { |l| l[:action] }
      expect(actions).to eq(%w[BUY BUY])
    end

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
