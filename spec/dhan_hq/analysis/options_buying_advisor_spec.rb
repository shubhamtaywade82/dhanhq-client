# frozen_string_literal: true

require "spec_helper"
require "DhanHQ"

RSpec.describe DhanHQ::Analysis::OptionsBuyingAdvisor do
  let(:data) do
    {
      meta: { exchange_segment: "IDX_I", instrument: "INDEX", security_id: "13", symbol: "NIFTY" },
      spot: 24_900.0,
      indicators: {
        m1: { rsi: 52.0, adx: 18.0, atr: 10.0, macd: { macd: 1.2, signal: 0.9, hist: 0.3 } },
        m5: { rsi: 55.0, adx: 24.0, atr: 18.0, macd: { macd: 1.6, signal: 1.2, hist: 0.4 } },
        m15: { rsi: 58.0, adx: 28.0, atr: 28.0, macd: { macd: 2.0, signal: 1.5, hist: 0.5 } },
        m60: { rsi: 62.0, adx: 40.0, atr: 60.0, macd: { macd: 2.5, signal: 2.0, hist: 0.5 } }
      },
      option_chain: [
        {
          strike: 24_900,
          ce: { ltp: 120.0, bid: 119.0, ask: 121.0, iv: 12.0, oi: 20_000, volume: 5000, delta: 0.5, tradable: true },
          pe: { ltp: 100.0, bid: 99.0, ask: 101.0, iv: 14.0, oi: 15_000, volume: 4000, delta: -0.5, tradable: true }
        },
        {
          strike: 24_950,
          ce: { ltp: 90.0, bid: 89.0, ask: 91.0, iv: 13.0, oi: 18_000, volume: 4500, delta: 0.4, tradable: true },
          pe: { ltp: 110.0, bid: 109.0, ask: 111.0, iv: 15.0, oi: 10_000, volume: 3000, delta: -0.6, tradable: true }
        }
      ]
    }
  end

  it "returns enter_long with CE recommendation in bullish regime" do
    out = described_class.new(data: data).call
    expect(out[:decision]).to eq(:enter_long)
    expect(out[:side]).to eq(:ce)
    expect(out[:strike]).to include(:recommended)
  end

  it "returns no_trade for unsupported instrument" do
    bad = data.dup
    bad[:meta] = { exchange_segment: "NSE_EQ", instrument: "EQUITY", security_id: "1333" }
    out = described_class.new(data: bad).call
    expect(out[:decision]).to eq(:no_trade)
  end
end
