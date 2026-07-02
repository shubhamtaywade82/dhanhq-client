# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::SquareOffAll do
  # rubocop:disable RSpec/VerifiedDoubles
  let(:position_with_qty) do
    double("position").tap do |pos|
      allow(pos).to receive(:[]).with(:net_quantity).and_return(50)
      allow(pos).to receive(:[]).with("netQuantity").and_return(50)
      allow(pos).to receive(:net_quantity).and_return(50)
    end
  end

  let(:position_zero_qty) do
    double("position").tap do |pos|
      allow(pos).to receive(:[]).with(:net_quantity).and_return(0)
      allow(pos).to receive(:[]).with("netQuantity").and_return(0)
      allow(pos).to receive(:net_quantity).and_return(0)
    end
  end
  # rubocop:enable RSpec/VerifiedDoubles

  let(:positions) { [position_with_qty, position_zero_qty] }

  before do
    allow(DhanHQ::Models::Position).to receive_messages(all: positions, exit_all!: { status: "OK" })
  end

  describe "#call" do
    it "fetches non-zero positions" do
      described_class.new.call
      expect(DhanHQ::Models::Position).to have_received(:all)
    end

    it "filters out zero-quantity positions" do
      result = described_class.new.call
      expect(result[:positions]).to eq([position_with_qty])
    end

    it "exits each non-zero position" do
      described_class.new.call
      expect(DhanHQ::Models::Position).to have_received(:exit_all!).once
    end

    it "reports exit results" do
      result = described_class.new.call
      expect(result[:exit_results]).to eq([{ status: "OK" }])
      expect(result[:exited_count]).to eq(1)
      expect(result[:failed_count]).to eq(0)
    end

    it "handles exit failures gracefully" do
      allow(DhanHQ::Models::Position).to receive(:exit_all!).and_raise(StandardError, "API error")

      result = described_class.new.call
      expect(result[:exited_count]).to eq(0)
      expect(result[:failed_count]).to eq(1)
      expect(result[:exit_results].first[:error]).to eq("API error")
    end

    # rubocop:disable RSpec/ExampleLength
    it "handles mixed success and failure" do
      position_a = double("position_a").tap do |pos| # rubocop:disable RSpec/VerifiedDoubles
        allow(pos).to receive(:[]).with(:net_quantity).and_return(10)
        allow(pos).to receive(:[]).with("netQuantity").and_return(10)
        allow(pos).to receive(:net_quantity).and_return(10)
      end
      position_b = double("position_b").tap do |pos| # rubocop:disable RSpec/VerifiedDoubles
        allow(pos).to receive(:[]).with(:net_quantity).and_return(20)
        allow(pos).to receive(:[]).with("netQuantity").and_return(20)
        allow(pos).to receive(:net_quantity).and_return(20)
      end

      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_a, position_b])

      call_count = 0
      allow(DhanHQ::Models::Position).to receive(:exit_all!) do
        call_count += 1
        raise StandardError, "fail" if call_count == 1

        { status: "OK" }
      end

      result = described_class.new.call
      expect(result[:exited_count]).to eq(1)
      expect(result[:failed_count]).to eq(1)
    end
    # rubocop:enable RSpec/ExampleLength

    it "returns empty results when no positions have quantity" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([position_zero_qty])

      result = described_class.new.call
      expect(result[:positions]).to be_empty
      expect(result[:exit_results]).to be_empty
      expect(result[:exited_count]).to eq(0)
    end
  end

  describe "#name" do
    it "returns class name" do
      expect(described_class.new.name).to include("SquareOffAll")
    end
  end
end
