# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Pipeline do
  let(:market_time) { Time.new(2024, 1, 2, 10, 0, 0, "+05:30") }
  let(:instrument) { FakeInstrument.build }
  let(:base_args) { { "quantity" => 1 } }

  def position_double(net_qty, urpl = 0, security_id: "1", product_type: "INTRADAY")
    double("position", net_qty: net_qty, unrealized_profit: urpl, realized_profit: 0, security_id: security_id,
                       exchange_segment: "NSE_FNO", product_type: product_type, trading_symbol: nil, cost_price: 100.0)
  end

  before do
    allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(
      double("funds", available_balance: 500_000)
    )
  end

  describe ".run! for a risk-reducing order" do
    let(:held) { position_double(75, -90_000, security_id: "52175") }
    let(:exit_args) do
      { "transaction_type" => "SELL", "security_id" => "52175", "exchange_segment" => "NSE_FNO",
        "product_type" => "INTRADAY", "order_type" => "STOP_LOSS_MARKET", "quantity" => 75 }
    end

    it "lets a stop-out through every limit (loss, position count, size, ASM)" do
      crowded = [held] + Array.new(25) { |i| position_double(1, 0, security_id: "x#{i}") }
      restricted = FakeInstrument.build(asm_gsm_flag: "Y", asm_gsm_category: "ASM")

      expect do
        described_class.run!(instrument: restricted, args: exit_args, now: market_time, positions: crowded)
      end.not_to raise_error
    end

    it "still validates the order itself" do
      expect do
        described_class.run!(instrument: instrument, args: exit_args.merge("quantity" => 0), now: market_time,
                             positions: [held])
      end.to raise_error(DhanHQ::RiskViolation, "Quantity must be > 0")
    end

    it "treats an order larger than the position as new exposure" do
      expect do
        described_class.run!(instrument: instrument, args: exit_args.merge("quantity" => 150), now: market_time,
                             positions: [held])
      end.to raise_error(DhanHQ::RiskViolation, "Quantity exceeds limit")
    end

    it "treats a different product type as new exposure" do
      expect do
        described_class.run!(instrument: instrument, args: exit_args.merge("product_type" => "MARGIN"),
                             now: market_time, positions: [held])
      end.to raise_error(DhanHQ::RiskViolation, "Quantity exceeds limit")
    end

    it "fetches positions once for the whole pipeline" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])

      described_class.run!(instrument: instrument, args: base_args, now: market_time)

      expect(DhanHQ::Models::Position).to have_received(:all).once
    end
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
