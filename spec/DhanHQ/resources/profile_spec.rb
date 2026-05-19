# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Profile, vcr: {
  cassette_name: "resources/profile",
  record: :once
} do
  subject(:profile_resource) { described_class.new }

  before do
    DhanHQ.configure_with_env
  end

  describe "#fetch" do
    it "returns profile metadata" do
      response = profile_resource.fetch

      expect(response).to be_a(Hash)
      expect(response).to include(
        "dhanClientId" => "1100003626",
        "tokenValidity" => "30/03/2025 15:37"
      )
    end
  end
end
