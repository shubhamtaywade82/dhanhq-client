# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Funds do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/fundlimit" }
  let(:fundlimit_body) do
    {
      availableBalance: 47_511.46,
      withdrawableAmount: 47_511.46,
      utilizedMargin: 3488.54,
      openOrdersMargin: 0.0,
      availableExposure: 2_376_073.0
    }.to_json
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#fetch" do
    it "GETs /v2/fundlimit" do
      stub_request(:get, base)
        .to_return(status: 200, body: fundlimit_body, headers: { "Content-Type" => "application/json" })

      resource.fetch

      expect(WebMock).to have_requested(:get, base)
    end

    it "sends the access-token header" do
      stub_request(:get, base)
        .to_return(status: 200, body: fundlimit_body, headers: { "Content-Type" => "application/json" })

      resource.fetch

      expect(WebMock).to have_requested(:get, base)
        .with(headers: { "access-token" => "test_access_token" })
    end

    it "returns the parsed fund details with indifferent access" do
      stub_request(:get, base)
        .to_return(status: 200, body: fundlimit_body, headers: { "Content-Type" => "application/json" })

      response = resource.fetch

      expect(response["availableBalance"]).to eq(47_511.46)
      expect(response[:withdrawableAmount]).to eq(47_511.46)
    end

    it "raises InvalidAuthenticationError on 401" do
      stub_request(:get, base).to_return(
        status: 401,
        body: { errorCode: "TT-401", errorMessage: "Token is invalid or expired." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.fetch }.to raise_error(DhanHQ::InvalidAuthenticationError, /TT-401/)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, base).to_return(
        status: 404,
        body: { errorCode: "TT-404", errorMessage: "Not found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.fetch }.to raise_error(DhanHQ::NotFoundError)
    end

    it "raises InputExceptionError on 400" do
      stub_request(:get, base).to_return(
        status: 400,
        body: { errorCode: "TT-400", errorMessage: "Bad request" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.fetch }.to raise_error(DhanHQ::InputExceptionError)
    end
  end
end
