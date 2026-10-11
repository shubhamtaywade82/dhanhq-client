# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Checks::MaxLoss do
  def position_double(urpl, realized = 0)
    double("position", unrealized_profit: urpl, realized_profit: realized)
  end

  describe ".run!" do
    it "passes when positions are profitable" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(5000)])

      expect { described_class.run! }.not_to raise_error
    end

    it "passes when loss is within daily limit" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(-10_000)])

      expect { described_class.run! }.not_to raise_error
    end

    it "passes when at daily loss limit" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(-50_000)])

      expect { described_class.run! }.not_to raise_error
    end

    it "raises when loss exceeds daily limit" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(-60_000)])

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
    end

    it "sums losses across all positions" do
      positions = [position_double(-30_000), position_double(-30_000)]
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
    end

    it "counts losses already booked today" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_double(-20_000, -40_000)])

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
    end

    it "never blocks a risk-reducing order" do
      expect { described_class.run!(positions: [position_double(-90_000)], reducing: true) }.not_to raise_error
    end

    it "honours a configured limit" do
      DhanHQ.configuration.risk_limits = { daily_max_loss: 5_000 }

      expect { described_class.run!(positions: [position_double(-6_000)]) }
        .to raise_error(DhanHQ::RiskViolation, /₹5000/)
    ensure
      DhanHQ.configuration.risk_limits = {}
    end

    it "nets profits against losses" do
      positions = [position_double(40_000), position_double(-100_000)]
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
