# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::Strangle do
  let(:chain) do
    [
      { strike: 24_000, option_type: "PE", security_id: "PE01", last_price: 50.0 },
      { strike: 24_200, option_type: "PE", security_id: "PE02", last_price: 80.0 },
      { strike: 24_400, option_type: "PE", security_id: "PE03", last_price: 120.0 },
      { strike: 24_600, option_type: "CE", security_id: "CE01", last_price: 130.0 },
      { strike: 24_800, option_type: "CE", security_id: "CE02", last_price: 90.0 },
      { strike: 25_000, option_type: "CE", security_id: "CE03", last_price: 55.0 },
    ]
  end

  let(:instrument) do
    # rubocop:disable RSpec/VerifiedDoubles
    double("instrument",
           ltp: { ltp: 24_500.0 },
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

    it "has defaults" do
      params = described_class.params
      expect(params[:quantity][:default]).to eq(50)
      expect(params[:offset_pct][:default]).to eq(1.0)
      expect(params[:stop_loss][:default]).to eq(200)
      expect(params[:target][:default]).to eq(400)
    end
  end

  describe "#call" do
    it "selects 2 legs for strangle" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:intent][:legs].length).to eq(2)
    end

    it "selects CE and PE legs" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      types = result[:intent][:legs].map { |l| l[:option_type] }
      expect(types).to eq(%w[CE PE])
    end

    it "both legs are BUY" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      actions = result[:intent][:legs].map { |l| l[:action] }
      expect(actions).to eq(%w[BUY BUY])
    end

    it "builds intent with correct fields" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("STRANGLE")
      expect(intent[:symbol]).to eq("NIFTY")
      expect(intent[:expiry]).to eq("2026-01-30")
      expect(intent[:quantity]).to eq(50)
      expect(intent[:stop_loss]).to eq(200)
      expect(intent[:target]).to eq(400)
      expect(intent[:note]).to include("Await human confirmation")
    end

    it "selects strikes offset from spot" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30", offset_pct: 1.0)
      ce_strike = result[:intent][:legs].find { |l| l[:option_type] == "CE" }[:strike]
      pe_strike = result[:intent][:legs].find { |l| l[:option_type] == "PE" }[:strike]

      expect(ce_strike).to be > 24_500
      expect(pe_strike).to be < 24_500
    end
  end
end
