# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Skills::Builtin::BullPutSpread do
  let(:chain) do
    [
      { strike: 24_100, option_type: "PE", security_id: "PE00" },
      { strike: 24_200, option_type: "PE", security_id: "PE01" },
      { strike: 24_300, option_type: "PE", security_id: "PE02" },
      { strike: 24_400, option_type: "PE", security_id: "PE03" },
      { strike: 24_500, option_type: "PE", security_id: "PE04" },
      { strike: 24_600, option_type: "CE", security_id: "CE01" },
      { strike: 24_800, option_type: "CE", security_id: "CE02" }
    ]
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
      allow(instrument).to receive(:option_chain).and_return([
                                                               { strike: 24_500, option_type: "PE", security_id: "PE01" }
                                                             ])

      expect do
        described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      end.to raise_error(ArgumentError, /insufficient strikes/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
