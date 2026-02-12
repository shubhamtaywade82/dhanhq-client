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
    it "returns a hash with required keys", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.daily(daily_params)

      expect(response).to be_a(Hash)
      %i[open high low close volume timestamp].each do |key|
        expect(response).to have_key(key)
        expect(response[key]).to be_an(Array)
      end
    end

    it "has consistent array lengths", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.daily(daily_params)

      size = response[:open].size
      expect(response[:high].size).to eq(size)
      expect(response[:low].size).to eq(size)
      expect(response[:close].size).to eq(size)
      expect(response[:volume].size).to eq(size)
      expect(response[:timestamp].size).to eq(size)
    end

    it "has valid timestamp and volume data", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.daily(daily_params)

      expect(response[:timestamp]).to all(be_a(Numeric))
      expect(response[:timestamp]).to all(be > 0)
      expect(response[:volume]).to all(be_a(Numeric))
      expect(response[:volume]).to all(be >= 0)
    end
  end

  describe ".intraday" do
    it "fetches intraday historical data", vcr: { cassette_name: "models/historical_data" } do
      response = historical_data_model.intraday(intraday_params)

      expect(response).to be_a(Hash)

      # The same keys for intraday data
      %i[open high low close volume timestamp].each do |key|
        expect(response).to have_key(key)
        expect(response[key]).to be_an(Array)
      end

      # We can also check for positive volumes, etc.
      expect(response[:volume]).to all(be_a(Numeric))
      expect(response[:timestamp]).to all(be_a(Numeric))
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
      allow(resource_double).to receive(:intraday).with(params).and_return({})

      expect(described_class.intraday(params)).to eq({})
      expect(resource_double).to have_received(:intraday).with(params)
    end
  end
end
