# frozen_string_literal: true

RSpec.describe DhanHQ::Models::HistoricalData, vcr: { cassette_name: "models/historical_data" } do
  subject(:historical_data_model) { described_class }

  before do
    # Ensure gem is configured and environment variables (CLIENT_ID, ACCESS_TOKEN) are available
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
      to_date: "2024-09-15"
    }
  end

  describe ".daily" do
    it "fetches daily historical data" do
      response = historical_data_model.daily(daily_params)

      # The return is expected to be a HashWithIndifferentAccess
      expect(response).to be_a(Hash)

      # The keys: :open, :high, :low, :close, :volume, :timestamp
      # Confirm each key is present and is an array
      %i[open high low close volume timestamp].each do |key|
        expect(response).to have_key(key)
        expect(response[key]).to be_an(Array)
      end

      # Optionally check that all arrays have same length
      size = response[:open].size
      expect(response[:high].size).to eq(size)
      expect(response[:low].size).to eq(size)
      expect(response[:close].size).to eq(size)
      expect(response[:volume].size).to eq(size)
      expect(response[:timestamp].size).to eq(size)

      # Check that timestamps are integers (epoch times), volumes are ints
      response[:timestamp].each do |ts|
        expect(ts).to be_a(Numeric)
        expect(ts).to be > 0
      end

      response[:volume].each do |v|
        expect(v).to be_a(Numeric)
        expect(v).to be >= 0
      end
    end
  end

  describe ".intraday" do
    it "fetches intraday historical data" do
      response = historical_data_model.intraday(intraday_params)

      expect(response).to be_a(Hash)

      # The same keys for intraday data
      %i[open high low close volume timestamp].each do |key|
        expect(response).to have_key(key)
        expect(response[key]).to be_an(Array)
      end

      # We can also check for positive volumes, etc.
      response[:volume].each { |v| expect(v).to be_a(Numeric) }
      response[:timestamp].each { |ts| expect(ts).to be_a(Numeric) }
    end
  end
end

RSpec.describe DhanHQ::Models::HistoricalData, "unit" do
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
    expect(resource_double).to receive(:intraday).with(params).and_return({})

    expect(described_class.intraday(params)).to eq({})
  end
end
