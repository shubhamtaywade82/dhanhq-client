# frozen_string_literal: true

RSpec.describe DhanHQ::Backtest::Result do
  def trade(pnl:)
    instance_double(DhanHQ::Backtest::Trade, pnl: pnl, win?: pnl.positive?)
  end

  describe "with no trades and no candles" do
    subject(:result) { described_class.new(trades: [], equity_curve: [], initial_capital: 100_000.0) }

    it "reports flat, empty metrics without dividing by zero" do
      expect(result.summary).to eq(
        total_return_pct: 0.0,
        num_trades: 0,
        win_rate: 0.0,
        avg_trade_pnl: 0.0,
        max_drawdown_pct: 0.0,
        final_equity: 100_000.0
      )
    end
  end

  describe "with a mix of winning and losing trades" do
    subject(:result) do
      described_class.new(
        trades: [trade(pnl: 500.0), trade(pnl: -200.0), trade(pnl: 300.0)],
        equity_curve: [100_000.0, 100_500.0, 100_300.0, 100_600.0],
        initial_capital: 100_000.0
      )
    end

    it "computes total return relative to initial capital" do
      expect(result.total_return_pct).to be_within(0.01).of(0.6) # 600 / 100_000 * 100
    end

    it "counts trades and win rate" do
      expect(result.num_trades).to eq(3)
      expect(result.win_rate).to be_within(0.01).of(66.67) # 2 of 3 won
    end

    it "averages pnl across all trades" do
      expect(result.avg_trade_pnl).to be_within(0.01).of(200.0) # (500 - 200 + 300) / 3
    end
  end

  describe "#max_drawdown_pct" do
    it "finds the largest peak-to-trough decline in the equity curve" do
      # peak 100_000 -> trough 90_000 is the largest decline (10%), even though
      # the curve later rises above the original peak.
      result = described_class.new(
        trades: [], equity_curve: [100_000.0, 95_000.0, 90_000.0, 98_000.0, 105_000.0], initial_capital: 100_000.0
      )

      expect(result.max_drawdown_pct).to be_within(0.01).of(10.0)
    end

    it "is 0.0 for a monotonically rising curve" do
      result = described_class.new(
        trades: [], equity_curve: [100_000.0, 101_000.0, 102_000.0], initial_capital: 100_000.0
      )

      expect(result.max_drawdown_pct).to eq(0.0)
    end
  end
end
