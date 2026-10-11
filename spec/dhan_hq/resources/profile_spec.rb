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

  describe "request wire format" do
    subject(:profile_resource) { described_class.new }

    let(:base) { "https://api.dhan.co/v2/profile" }

    before do
      ENV["DHAN_CLIENT_ID"] = "test_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "GETs /v2/profile with the access-token header" do
      stub_request(:get, base).to_return(
        status: 200,
        body: { dhanClientId: "1100003626", tokenValidity: "30/03/2025 15:37" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      profile_resource.fetch

      expect(WebMock).to have_requested(:get, base)
        .with(headers: { "access-token" => "test_access_token" })
    end

    it "returns profile fields with indifferent access" do
      stub_request(:get, base).to_return(
        status: 200,
        body: { dhanClientId: "1100003626", tokenValidity: "30/03/2025 15:37", activeSegments: %w[NSE BSE] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      response = profile_resource.fetch

      expect(response[:dhanClientId]).to eq("1100003626")
      expect(response["activeSegments"]).to eq(%w[NSE BSE])
    end

    it "raises InvalidAuthenticationError on 401" do
      stub_request(:get, base).to_return(
        status: 401,
        body: { errorCode: "TT-401", errorMessage: "Token is invalid or expired." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { profile_resource.fetch }.to raise_error(DhanHQ::InvalidAuthenticationError)
    end
  end
end
