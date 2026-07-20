# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Checks::PositionLimits do
  def position_double(net_qty)
    double("position").tap do |p|
      allow(p).to receive(:[]).with(:net_quantity).and_return(net_qty)
      allow(p).to receive(:[]).with("netQuantity").and_return(net_qty)
      allow(p).to receive(:net_quantity).and_return(net_qty)
    end
  end

  describe ".run!" do
    it "passes when under max position limit" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])

      expect { described_class.run! }.not_to raise_error
    end

    it "passes when at max position limit" do
      positions = Array.new(19) { position_double(1) }
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.not_to raise_error
    end

    it "raises when over max position limit" do
      positions = Array.new(20) { position_double(1) }
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.to raise_error(DhanHQ::RiskViolation, /open positions exceeded/)
    end

    it "ignores zero-quantity positions in count" do
      positions = Array.new(25) { |i| position_double(i < 19 ? 1 : 0) }
      allow(DhanHQ::Models::Position).to receive(:all).and_return(positions)

      expect { described_class.run! }.not_to raise_error
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
