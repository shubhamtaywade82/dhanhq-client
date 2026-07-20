# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Pipeline do
  let(:market_time) { Time.new(2024, 1, 2, 10, 0, 0, "+05:30") }
  let(:instrument) { FakeInstrument.build }
  let(:base_args) { { "quantity" => 1 } }

  before do
    allow(DhanHQ::Models::Position).to receive(:all).and_return([])
    allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(
      double("funds", available_balance: 500_000)
    )
  end

  describe ".run!" do
    context "with valid equity inputs" do
      it "passes without error" do
        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: market_time,
            type: :equity
          )
        end.not_to raise_error
      end
    end

    context "when trading is disabled" do
      it "raises RiskViolation" do
        disabled = FakeInstrument.build(buy_sell_indicator: "N")

        expect do
          described_class.run!(
            instrument: disabled,
            args: base_args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Trading disabled for instrument")
      end
    end

    context "when ASM/GSM restriction is active" do
      it "raises RiskViolation" do
        restricted = FakeInstrument.build(asm_gsm_flag: "Y", asm_gsm_category: "ASM")

        expect do
          described_class.run!(
            instrument: restricted,
            args: base_args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, %r{ASM/GSM restricted})
      end
    end

    context "when quantity is zero" do
      it "raises RiskViolation" do
        args = { "quantity" => 0 }

        expect do
          described_class.run!(
            instrument: instrument,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Quantity must be > 0")
      end
    end

    context "when quantity exceeds limit" do
      it "raises RiskViolation" do
        args = { "quantity" => 11 }

        expect do
          described_class.run!(
            instrument: instrument,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Quantity exceeds limit")
      end
    end

    context "when notional exceeds limit" do
      it "raises RiskViolation" do
        args = { "quantity" => 10, "price" => 11_000 }

        expect do
          described_class.run!(
            instrument: instrument,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Notional exceeds limit")
      end
    end

    context "when order type is invalid" do
      it "raises RiskViolation" do
        args = base_args.merge("order_type" => "STOP_LOSS")

        expect do
          described_class.run!(
            instrument: instrument,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Invalid order type")
      end
    end

    context "when bracket order but instrument does not support it" do
      it "raises RiskViolation" do
        no_bo = FakeInstrument.build(bracket_flag: "N")
        args = base_args.merge("product_type" => "BO")

        expect do
          described_class.run!(
            instrument: no_bo,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Bracket orders not supported")
      end
    end

    context "when cover order but instrument does not support it" do
      it "raises RiskViolation" do
        no_co = FakeInstrument.build(cover_flag: "N")
        args = base_args.merge("product_type" => "CO")

        expect do
          described_class.run!(
            instrument: no_co,
            args: args,
            now: market_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Cover orders not supported")
      end
    end

    context "when market is closed" do
      it "raises RiskViolation" do
        closed_time = Time.new(2024, 1, 2, 8, 0, 0, "+05:30")

        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: closed_time,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Market is closed")
      end
    end

    context "when market is about to close" do
      it "passes at 15:29" do
        near_close = Time.new(2024, 1, 2, 15, 29, 0, "+05:30")

        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: near_close,
            type: :equity
          )
        end.not_to raise_error
      end

      it "raises at 15:31" do
        past_close = Time.new(2024, 1, 2, 15, 31, 0, "+05:30")

        expect do
          described_class.run!(
            instrument: instrument,
            args: base_args,
            now: past_close,
            type: :equity
          )
        end.to raise_error(DhanHQ::RiskViolation, "Market is closed")
      end
    end
  end

  context "with options inputs" do
    it "raises RiskViolation when instrument is not an index" do
      non_index = FakeInstrument.build(instrument_type: "EQUITY")

      expect do
        described_class.run!(
          instrument: non_index,
          args: base_args.merge("stop_loss" => 80, "target" => 100),
          now: market_time,
          type: :options
        )
      end.to raise_error(DhanHQ::RiskViolation, "Options only allowed on index")
    end

    it "raises RiskViolation when stop loss is missing" do
      expect do
        described_class.run!(
          instrument: instrument,
          args: base_args.merge("target" => 100),
          now: market_time,
          type: :options
        )
      end.to raise_error(DhanHQ::RiskViolation, "Stop loss required")
    end

    it "raises RiskViolation when target is missing" do
      expect do
        described_class.run!(
          instrument: instrument,
          args: base_args.merge("stop_loss" => 80),
          now: market_time,
          type: :options
        )
      end.to raise_error(DhanHQ::RiskViolation, "Target required")
    end

    it "raises RiskViolation when risk reward is invalid" do
      args = base_args.merge("stop_loss" => 120, "target" => 100)

      expect do
        described_class.run!(
          instrument: instrument,
          args: args,
          now: market_time,
          type: :options
        )
      end.to raise_error(DhanHQ::RiskViolation, "Invalid risk-reward")
    end

    it "passes with valid options inputs" do
      args = base_args.merge("stop_loss" => 80, "target" => 100)

      expect do
        described_class.run!(
          instrument: instrument,
          args: args,
          now: market_time,
          type: :options
        )
      end.not_to raise_error
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
