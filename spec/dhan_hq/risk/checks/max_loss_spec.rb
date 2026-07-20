# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Checks::MaxLoss do
  def position_double(urpl)
    double("position").tap do |p|
      allow(p).to receive(:[]).with(:unrealized_profit_loss).and_return(urpl)
      allow(p).to receive(:[]).with("unrealized_profit_loss").and_return(urpl)
      allow(p).to receive(:unrealized_profit_loss).and_return(urpl)
    end
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

    it "nets profits against losses" do
      positions = [position_double(40_000), position_double(-100_000)]
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
