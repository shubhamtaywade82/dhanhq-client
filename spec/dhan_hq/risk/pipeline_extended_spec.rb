# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Pipeline do
  let(:market_time) { Time.new(2024, 1, 2, 10, 0, 0, "+05:30") }
  let(:instrument) { FakeInstrument.build }
  let(:base_args) { { "quantity" => 1 } }

  def position_double(net_qty, urpl = 0)
    double("position", net_qty: net_qty, unrealized_profit: urpl)
  end

  before do
    allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(
      double("funds", available_balance: 500_000)
    )
  end

  describe ".run! with additional checks" do
    context "when PositionLimits check fails" do
      it "raises RiskViolation" do
        positions = Array.new(20) { position_double(1) }
        allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, /open positions exceeded/)
      end
    end

    context "when MaxLoss check fails" do
      it "raises RiskViolation" do
        allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(1, -60_000)])

        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
