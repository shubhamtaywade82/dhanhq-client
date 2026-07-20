# frozen_string_literal: true

require "spec_helper"
require "dhan_hq/analysis"

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

  # rubocop:disable RSpec/ExampleLength
  it "auto-fetches and normalizes the option chain against the real nested OptionChain shape" do
    without_chain = data.dup
    without_chain.delete(:option_chain)

    allow(DhanHQ::Models::OptionChain).to receive_messages(fetch_expiry_list: ["2026-01-30"], fetch: {
      last_price: 24_900.0,
      strikes: [
        { strike: 24_900.0,
          call: { last_price: 120.0, top_bid_price: 119.0, top_ask_price: 121.0, implied_volatility: 12.0,
                  oi: 20_000, volume: 5000, security_id: "CE1", greeks: { delta: 0.5, gamma: 0.01, vega: 5.0, theta: -2.0 } },
          put: { last_price: 100.0, top_bid_price: 99.0, top_ask_price: 101.0, implied_volatility: 14.0,
                 oi: 15_000, volume: 4000, security_id: "PE1", greeks: { delta: -0.5, gamma: 0.01, vega: 5.0, theta: -2.0 } } },
        { strike: 24_950.0,
          call: { last_price: 90.0, top_bid_price: 89.0, top_ask_price: 91.0, implied_volatility: 13.0,
                  oi: 18_000, volume: 4500, security_id: "CE2", greeks: { delta: 0.4, gamma: 0.01, vega: 5.0, theta: -2.0 } },
          put: { last_price: 110.0, top_bid_price: 109.0, top_ask_price: 111.0, implied_volatility: 15.0,
                 oi: 10_000, volume: 3000, security_id: "PE2", greeks: { delta: -0.6, gamma: 0.01, vega: 5.0, theta: -2.0 } } }
      ]
    }.with_indifferent_access)

    out = described_class.new(data: without_chain).call

    expect(DhanHQ::Models::OptionChain).to have_received(:fetch)
    expect(out[:decision]).to eq(:enter_long)
    expect(out[:strike]).to include(:recommended)
  end
  # rubocop:enable RSpec/ExampleLength
end
