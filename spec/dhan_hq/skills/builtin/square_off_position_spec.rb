# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::SquareOffPosition do
  # rubocop:disable RSpec/VerifiedDoubles
  let(:position) do
    double("position").tap do |pos|
      allow(pos).to receive(:[]).with(:exchange_segment).and_return("IDX_I")
      allow(pos).to receive(:[]).with("exchange_segment").and_return("IDX_I")
      allow(pos).to receive(:[]).with(:trading_symbol).and_return("NIFTY")
      allow(pos).to receive(:[]).with("tradingSymbol").and_return("NIFTY")
      allow(pos).to receive(:[]).with(:security_id).and_return("SEC001")
      allow(pos).to receive(:[]).with("securityId").and_return("SEC001")
      allow(pos).to receive(:[]).with(:net_quantity).and_return(50)
      allow(pos).to receive(:[]).with("netQuantity").and_return(50)
      allow(pos).to receive(:net_quantity).and_return(50)
    end
  end
  # rubocop:enable RSpec/VerifiedDoubles

  before do
    allow(DhanHQ::Models::Position).to receive_messages(all: [position], exit_all!: { status: "OK" })
  end

  describe "parameter definitions" do
    it "requires symbol and exchange_segment" do
      params = described_class.params
      expect(params[:symbol][:required]).to be true
      expect(params[:exchange_segment][:required]).to be true
    end
  end

  describe "#call" do
    it "finds matching position by symbol and exchange" do
      described_class.new.call(symbol: "NIFTY", exchange_segment: "IDX_I")
      expect(DhanHQ::Models::Position).to have_received(:all)
    end

    it "populates position details in context" do
      result = described_class.new.call(symbol: "NIFTY", exchange_segment: "IDX_I")
      expect(result[:security_id]).to eq("SEC001")
      expect(result[:trading_symbol]).to eq("NIFTY")
      expect(result[:net_quantity]).to eq(50)
    end

    it "exits the position" do
      described_class.new.call(symbol: "NIFTY", exchange_segment: "IDX_I")
      expect(DhanHQ::Models::Position).to have_received(:exit_all!)
    end

    it "reports exit result" do
      result = described_class.new.call(symbol: "NIFTY", exchange_segment: "IDX_I")
      expect(result[:exited]).to be true
      expect(result[:exit_result]).to eq({ status: "OK" })
    end

    it "raises when position not found" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])

      expect do
        described_class.new.call(symbol: "RELIANCE", exchange_segment: "NSE_EQ")
      end.to raise_error(ArgumentError, /No open position found/)
    end
  end
end
