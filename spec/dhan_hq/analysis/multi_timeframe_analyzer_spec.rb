# frozen_string_literal: true

require "spec_helper"
require "DhanHQ"

RSpec.describe DhanHQ::Analysis::MultiTimeframeAnalyzer do
  let(:valid_data) do
    {
      meta: { exchange_segment: "IDX_I", instrument: "INDEX", security_id: "13" },
      indicators: {
        m1: { rsi: 52.0, adx: 18.0, atr: 10.0, macd: { macd: 1.2, signal: 0.9, hist: 0.3 } },
        m5: { rsi: 54.0, adx: 22.0, atr: 20.0, macd: { macd: 2.2, signal: 1.9, hist: 0.3 } },
        m15: { rsi: 48.0, adx: 12.0, atr: 30.0, macd: { macd: -0.2, signal: 0.1, hist: -0.3 } }
      }
    }
  end

  it "validates input and returns a structured summary" do
    analyzer = described_class.new(data: valid_data)
    out = analyzer.call

    expect(out).to be_a(Hash)
    expect(out[:meta]).to include(:security_id, :instrument, :exchange_segment)
    expect(out[:summary]).to include(:bias, :setup, :confidence, :rationale, :trend_strength)
  end

  it "raises on invalid input" do
    expect do
      described_class.new(data: { meta: {}, indicators: nil }).call
    end.to raise_error(ArgumentError)
  end
end
