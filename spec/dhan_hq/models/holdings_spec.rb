# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Holding, vcr: {
  cassette_name: "models/holdings",
  record: :once
} do
  before do
    # Make sure your DhanHQ gem is configured with CLIENT_ID and ACCESS_TOKEN
    DhanHQ.configure_with_env
  end

  describe ".all" do
    it "fetches all holdings" do
      holdings = described_class.all
      expect(holdings).to be_an(Array)

      # At least check if we got an array of DhanHQ::Models::Holding
      holdings.each do |holding|
        expect(holding).to be_a(described_class)

        # Optionally check some attributes you expect:
        expect(holding.security_id).to be_a(String)
        expect(holding.trading_symbol).to be_a(String).or be_nil
        expect(holding.exchange).to be_a(String).or be_nil
      end
    end
  end
end

RSpec.describe DhanHQ::Models::Holding, "unit" do
  let(:resource_double) { instance_double(DhanHQ::Resources::Holdings) }

  before do
    described_class.instance_variable_set(:@resource, nil)
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  it "returns [] when API raises no holdings error" do
    allow(resource_double).to receive(:all).and_raise(DhanHQ::NoHoldingsError)

    expect(described_class.all).to eq([])
  end

  it "converts holdings into hashes" do
    allow(resource_double).to receive(:all).and_return([{ "exchange" => "NSE", "securityId" => "1333" }])

    holding = described_class.all.first
    expect(holding.to_h[:exchange]).to eq("NSE")
  end
end
