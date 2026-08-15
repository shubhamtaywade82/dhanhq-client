# frozen_string_literal: true

RSpec.describe DhanHQ::Backtest::Runner do
  def build_candles(count, start_price: 100.0)
    (0...count).map do |i|
      open = start_price + i
      DhanHQ::MarketData::OHLCSeries::Candle.new(
        Time.new(2024, 1, 1) + (i * 86_400), open, open + 2, open - 2, open + 1, 1_000, nil
      )
    end
  end

  # Signals fire on window *size* rather than price, so tests can pin down exactly
  # which candle a signal fires on regardless of the synthetic price series.
  let(:enter_on_third_bar_strategy) do
    Class.new(DhanHQ::Strategy::Base) do
      entry_rule(:third_bar) { |data, _params| data.size == 3 }
    end
  end

  let(:enter_and_exit_strategy) do
    Class.new(DhanHQ::Strategy::Base) do
      entry_rule(:third_bar) { |data, _params| data.size == 3 }
      exit_rule(:fifth_bar) { |data, _params| data.size == 5 }
    end
  end

  let(:series) { DhanHQ::MarketData::OHLCSeries.new(build_candles(7)) }

  describe "#run" do
    it "fills the entry at the next candle's open, not the signal candle itself" do
      result = described_class.new(strategy: enter_and_exit_strategy.new, data: series, initial_capital: 100_000.0).run
      trade = result.trades.first

      expect(trade.entry_price).to eq(series.candles[3].open) # signal fires at index 2 (window size 3)
      expect(trade.entry_time).to eq(series.candles[3].timestamp)
    end

    it "fills the exit at the next candle's open after the exit signal bar" do
      result = described_class.new(strategy: enter_and_exit_strategy.new, data: series, initial_capital: 100_000.0).run
      trade = result.trades.first

      expect(trade.exit_price).to eq(series.candles[5].open) # exit signal fires at index 4 (window size 5)
      expect(trade.exit_reason).to eq(:signal)
    end

    it "sizes the position using the quantity callable, evaluated at the fill price" do
      quantity = ->(equity, price) { (equity / price).floor }
      result = described_class.new(
        strategy: enter_and_exit_strategy.new, data: series, initial_capital: 100_000.0, quantity: quantity
      ).run

      fill_price = series.candles[3].open
      expect(result.trades.first.quantity).to eq((100_000.0 / fill_price).floor)
    end

    it "produces one equity curve point per candle, flat until the position is actually filled" do
      result = described_class.new(strategy: enter_and_exit_strategy.new, data: series, initial_capital: 100_000.0).run

      expect(result.equity_curve.size).to eq(series.candles.size)
      # Signal fires at index 2, but the fill (and therefore any unrealized pnl) doesn't
      # happen until index 3 — equity must stay exactly at initial_capital through index 2.
      expect(result.equity_curve[2]).to eq(100_000.0)
    end

    it "charges fees on both legs when a fees callable is given" do
      fees = ->(trade_value) { trade_value * 0.001 }
      result = described_class.new(
        strategy: enter_and_exit_strategy.new, data: series, initial_capital: 100_000.0, fees: fees
      ).run
      trade = result.trades.first

      entry_value = trade.entry_price * trade.quantity
      exit_value = trade.exit_price * trade.quantity
      expect(trade.fees).to be_within(0.001).of((entry_value * 0.001) + (exit_value * 0.001))
    end

    it "returns an empty result for an empty series without raising" do
      empty_series = DhanHQ::MarketData::OHLCSeries.new([])
      strategy = Class.new(DhanHQ::Strategy::Base).new

      result = described_class.new(strategy: strategy, data: empty_series, initial_capital: 100_000.0).run

      expect(result.trades).to eq([])
      expect(result.equity_curve).to eq([])
    end
  end

  context "when the strategy never signals an exit" do
    it "force-closes the open position at the last candle's close" do
      result = described_class.new(strategy: enter_on_third_bar_strategy.new, data: series, initial_capital: 100_000.0).run
      trade = result.trades.first

      expect(trade.exit_reason).to eq(:end_of_data)
      expect(trade.exit_price).to eq(series.candles.last.close)
      expect(trade.exit_time).to eq(series.candles.last.timestamp)
    end
  end

  context "with max_bars_held set" do
    it "force-exits once the position has been held for the configured number of bars" do
      result = described_class.new(
        strategy: enter_on_third_bar_strategy.new, data: series, initial_capital: 100_000.0, max_bars_held: 1
      ).run
      trade = result.trades.first

      expect(trade.exit_reason).to eq(:max_bars_held)
    end

    it "never force-exits when left at the default nil" do
      result = described_class.new(strategy: enter_on_third_bar_strategy.new, data: series, initial_capital: 100_000.0).run
      trade = result.trades.first

      expect(trade.exit_reason).to eq(:end_of_data)
    end
  end

  context "with a risk rule that always violates" do
    let(:strategy_with_risk_rule) do
      Class.new(DhanHQ::Strategy::Base) do
        entry_rule(:third_bar) { |data, _params| data.size == 3 }
        risk_rule(:always_violate) { |_context, _params| false }
      end
    end

    it "force-exits on the bar immediately after entry" do
      result = described_class.new(strategy: strategy_with_risk_rule.new, data: series, initial_capital: 100_000.0).run
      trade = result.trades.first

      expect(trade.exit_reason).to eq(:risk_violation)
    end
  end

  it "never holds more than one position at a time" do
    flip_flopping_strategy = Class.new(DhanHQ::Strategy::Base) do
      entry_rule(:always) { |_data, _params| true }
      exit_rule(:never) { |_data, _params| false }
    end

    result = described_class.new(strategy: flip_flopping_strategy.new, data: series, initial_capital: 100_000.0).run

    expect(result.trades.size).to eq(1)
  end
end
