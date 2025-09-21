# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Profile, vcr: {
  cassette_name: "models/profile",
  record: :once
} do
  before do
    DhanHQ.configure_with_env
  end

  describe ".fetch" do
    it "returns a profile model" do
      profile = described_class.fetch

      expect(profile).to be_a(described_class)
      expect(profile.dhan_client_id).to eq("1100003626")
      expect(profile.token_validity).to eq("30/03/2025 15:37")
    end
  end
end

RSpec.describe DhanHQ::Models::Profile, "unit" do
  let(:resource_double) { instance_double(DhanHQ::Resources::Profile) }

  before do
    described_class.instance_variable_set(:@resource, nil)
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  it "returns nil when response is not a hash" do
    allow(resource_double).to receive(:fetch).and_return([])

    expect(described_class.fetch).to be_nil
  end
end
