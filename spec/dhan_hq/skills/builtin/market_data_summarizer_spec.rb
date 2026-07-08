# frozen_string_literal: true
# rubocop:disable RSpec/VerifiedDoubles
# rubocop:disable RSpec/ReceiveMessages
# rubocop:disable Naming/VariableNumber
# rubocop:disable Lint/AmbiguousOperatorPrecedence

RSpec.describe DhanHQ::Skills::Builtin::MarketDataSummarizer do
  let(:instrument) do
    double(
      "instrument",
      security_id: "2885",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY"
    )
  end

  let(:candles) do
    # Generate 60 test candles with an upward trend for testing indicators
    (1..60).map do |i|
      {
        timestamp: Time.now - (60 - i) * 86_400,
        open: 100.0 + i,
        high: 105.0 + i,
        low: 95.0 + i,
        close: 100.0 + i,
        volume: 10_000
      }
    end
  end

  let(:option_chain_data) do
    {
      last_price: 160.0,
      strikes: [
        { strike: 158.0, call: { security_id: "CE158", last_price: 5.0, oi: 100_000 }, put: { security_id: "PE158", last_price: 1.0, oi: 50_000 } },
        { strike: 159.0, call: { security_id: "CE159", last_price: 4.0, oi: 120_000 }, put: { security_id: "PE159", last_price: 2.0, oi: 60_000 } },
        { strike: 160.0, call: { security_id: "CE160", last_price: 3.0, oi: 150_000 }, put: { security_id: "PE160", last_price: 3.0, oi: 150_000 } },
        { strike: 161.0, call: { security_id: "CE161", last_price: 2.0, oi: 90_000 }, put: { security_id: "PE161", last_price: 4.0, oi: 180_000 } },
        { strike: 162.0, call: { security_id: "CE162", last_price: 1.0, oi: 80_000 }, put: { security_id: "PE162", last_price: 5.0, oi: 200_000 } }
      ]
    }
  end

  before do
    allow(DhanHQ::Models::Instrument).to receive(:find).and_return(instrument)
    allow(DhanHQ::Models::HistoricalData).to receive(:daily).and_return(candles)
    allow(DhanHQ::Models::OptionChain).to receive(:fetch_expiry_list).and_return(["2026-01-30"])
    allow(DhanHQ::Models::OptionChain).to receive(:fetch).and_return(option_chain_data)
  end

  describe "parameter definitions" do
    it "requires underlying_symbol" do
      params = described_class.params
      expect(params[:underlying_symbol][:required]).to be true
    end

    it "has reasonable defaults" do
      params = described_class.params
      expect(params[:mode][:default]).to eq("both")
      expect(params[:interval][:default]).to eq("DAY")
      expect(params[:range_days][:default]).to eq(30)
      expect(params[:expiry][:default]).to eq("nearest")
      expect(params[:strike_range][:default]).to eq(5)
    end
  end

  describe "#call" do
    it "fetches daily candles and calculates correct SMAs and returns" do
      result = described_class.new.call(underlying_symbol: "RELIANCE")
      tech = result[:technical_summary]

      expect(tech[:ltp]).to eq(160.0)
      # Last 20 closes are 141..160. sum = 3010. average = 150.5
      expect(tech[:sma_20]).to eq(150.5)
      # Last 50 closes are 111..160. average = 135.5
      expect(tech[:sma_50]).to eq(135.5)
      # 5-day return: (160 - 155) / 155 * 100 = 3.23%
      expect(tech[:return_5d_pct]).to eq(3.23)
    end

    it "calculates options PCR and support/resistance walls" do
      result = described_class.new.call(underlying_symbol: "RELIANCE")
      opts = result[:option_chain_summary]

      expect(opts[:spot]).to eq(160.0)
      # Total CE OI = 100k + 120k + 150k + 90k + 80k = 540k
      # Total PE OI = 50k + 60k + 150k + 180k + 200k = 640k
      # PCR = 640 / 540 = 1.185
      expect(opts[:pcr]).to eq(1.185)

      # Call Wall (Resistance): CE160 (150k), CE159 (120k), CE158 (100k)
      expect(opts[:resistance_walls].first[:strike]).to eq(160.0)

      # Put Wall (Support): PE162 (200k), PE161 (180k), PE160 (150k)
      expect(opts[:support_walls].first[:strike]).to eq(162.0)
    end

    it "restricts option strikes to strike_range around ATM" do
      result = described_class.new.call(underlying_symbol: "RELIANCE", strike_range: 1)
      opts = result[:option_chain_summary]

      # With strike_range: 1 and closest strike 160.0, we should get 159.0, 160.0, 161.0
      expect(opts[:strikes].map { |s| s[:strike] }).to eq([159.0, 160.0, 161.0])
    end
  end
end
