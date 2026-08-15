# frozen_string_literal: true

RSpec.describe DhanHQ::Backtest::Trade do
  subject(:trade) do
    described_class.new(
      entry_time: Time.new(2024, 1, 1), entry_price: 100.0,
      exit_time: Time.new(2024, 1, 2), exit_price: 110.0,
      quantity: 10, exit_reason: :signal, fees: 5.0
    )
  end

  describe "#pnl" do
    it "is the price move times quantity, minus fees" do
      expect(trade.pnl).to eq(95.0) # ((110 - 100) * 10) - 5
    end

    it "is negative when the exit price is below entry" do
      losing = described_class.new(entry_price: 100.0, exit_price: 90.0, quantity: 10, fees: 0.0)

      expect(losing.pnl).to eq(-100.0)
    end
  end

  describe "#pnl_pct" do
    it "expresses pnl as a percentage of entry value" do
      expect(trade.pnl_pct).to be_within(0.01).of(9.5) # 95 / (100 * 10) * 100
    end

    it "returns 0.0 when entry value is zero rather than dividing by zero" do
      zero_entry = described_class.new(entry_price: 0.0, exit_price: 10.0, quantity: 5, fees: 0.0)

      expect(zero_entry.pnl_pct).to eq(0.0)
    end
  end

  describe "#win?" do
    it "is true for a profitable trade" do
      expect(trade.win?).to be true
    end

    it "is false for a break-even or losing trade" do
      breakeven = described_class.new(entry_price: 100.0, exit_price: 100.0, quantity: 10, fees: 0.0)

      expect(breakeven.win?).to be false
    end
  end
end
