# frozen_string_literal: true

RSpec.describe DhanHQ::Models::HistoricalData do
  subject(:historical_data_model) { described_class }

  before do
    # Ensure gem is configured and environment variables (DHAN_CLIENT_ID, DHAN_ACCESS_TOKEN) are available
    DhanHQ.configure_with_env
  end

  let(:daily_params) do
    {
      security_id: "1333",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY",
      expiry_code: 0,
      from_date: "2024-01-01",
      to_date: "2024-01-31"
    }
  end

  let(:intraday_params) do
    {
      security_id: "1333",
      exchange_segment: "NSE_EQ",
      instrument: "EQUITY",
      interval: "15", # 1, 5, 15, 25, 60
      from_date: "2024-09-11",
      to_date: "2024-09-13"
    }
  end

  describe ".daily" do
    it "returns an array of candle hashes", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.daily(daily_params)

      expect(response).to be_an(Array)
      candle = response.first
      expect(candle).to be_a(Hash)
      %i[open high low close volume timestamp].each do |key|
        expect(candle).to have_key(key)
      end
    end

    it "has valid timestamp and volume data", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.daily(daily_params)
      candle = response.first

      expect(candle[:timestamp]).to be_a(Time).or be_a(Numeric)
      expect(candle[:volume]).to be_a(Numeric)
      expect(candle[:volume]).to be >= 0
    end
  end

  describe ".intraday" do
    it "fetches intraday historical data", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.intraday(intraday_params)

      expect(response).to be_an(Array)
      candle = response.first
      expect(candle).to be_a(Hash)

      # The same keys for intraday data
      %i[open high low close volume timestamp].each do |key|
        expect(candle).to have_key(key)
      end

      # We can also check for positive volumes, etc.
      expect(candle[:volume]).to be_a(Numeric)
      expect(candle[:timestamp]).to be_a(Time).or be_a(Numeric)
    end

    it "validates intraday data with timestamp format and oi" do
      # This is a unit test since we don't have a VCR cassette for this specific call
      resource_double = instance_double(DhanHQ::Resources::HistoricalData)
      allow(described_class).to receive(:resource).and_return(resource_double)

      full_params = {
        security_id: "1333",
        exchange_segment: "NSE_EQ",
        instrument: "EQUITY",
        interval: "1",
        oi: false,
        from_date: "2024-09-11 09:30:00",
        to_date: "2024-09-15 13:00:00"
      }

      allow(resource_double).to receive(:intraday).with(full_params).and_return({})
      described_class.intraday(full_params)
      expect(resource_double).to have_received(:intraday).with(full_params)
    end
  end

  describe "unit tests" do
    let(:resource_double) { instance_double(DhanHQ::Resources::HistoricalData) }
    let(:params) do
      {
        security_id: "1333",
        exchange_segment: "NSE_EQ",
        instrument: "EQUITY",
        from_date: "2024-01-01",
        to_date: "2024-01-02"
      }
    end

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "passes through non-success responses" do
      payload = { status: "error" }
      allow(resource_double).to receive(:daily).and_return(payload)

      expect(described_class.daily(params)).to eq(payload)
    end

    it "delegates intraday calls" do
      intraday_params = params.merge(interval: "5")
      allow(resource_double).to receive(:intraday).with(intraday_params).and_return({})

      expect(described_class.intraday(intraday_params)).to eq({})
      expect(resource_double).to have_received(:intraday).with(intraday_params)
    end
  end
end
