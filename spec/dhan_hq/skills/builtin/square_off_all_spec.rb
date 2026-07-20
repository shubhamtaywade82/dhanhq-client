# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::SquareOffAll do
  # rubocop:disable RSpec/VerifiedDoubles
  let(:position_with_qty) { double("position", net_qty: 50) }
  let(:position_zero_qty) { double("position", net_qty: 0) }
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

    it "handles mixed success and failure" do
      position_a = double("position_a", net_qty: 10) # rubocop:disable RSpec/VerifiedDoubles
      position_b = double("position_b", net_qty: 20) # rubocop:disable RSpec/VerifiedDoubles

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
