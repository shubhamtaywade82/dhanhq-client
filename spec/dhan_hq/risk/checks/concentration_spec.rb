# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Checks::Concentration do
  describe ".run!" do
    let(:funds) do
      double("Funds", available_balance: 100_000)
    end

    before do
      allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(funds)
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])
    end

    def position_double(net_qty, price, symbol: "RELIANCE")
      double("position").tap do |p|
        allow(p).to receive(:[]).with(:net_quantity).and_return(net_qty)
        allow(p).to receive(:[]).with("netQuantity").and_return(net_qty)
        allow(p).to receive(:[]).with(:trading_symbol).and_return(symbol)
        allow(p).to receive(:[]).with("tradingSymbol").and_return(symbol)
        allow(p).to receive(:[]).with(:security_id).and_return("2885")
        allow(p).to receive(:[]).with("securityId").and_return("2885")
        allow(p).to receive(:[]).with(:ltp).and_return(price)
        allow(p).to receive(:[]).with("ltp").and_return(price)
        allow(p).to receive(:[]).with(:last_price).and_return(price)
        allow(p).to receive(:[]).with("lastPrice").and_return(price)
        allow(p).to receive_messages(net_quantity: net_qty, trading_symbol: symbol, ltp: price)
      end
    end

    it "passes when no symbol is specified" do
      expect { described_class.run!(args: {}) }.not_to raise_error
    end

    it "passes when no positions exist for the symbol" do
      expect { described_class.run!(args: { "trading_symbol" => "RELIANCE" }) }.not_to raise_error
    end

    it "passes when concentration is within limits" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(10, 1000.0)])

      expect { described_class.run!(args: { "trading_symbol" => "RELIANCE" }) }.not_to raise_error
    end

    it "raises when concentration exceeds limits" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(500, 5000.0)])

      expect { described_class.run!(args: { "trading_symbol" => "RELIANCE" }) }.to raise_error(DhanHQ::RiskViolation, /Concentration/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
