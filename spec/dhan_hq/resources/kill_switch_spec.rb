# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::KillSwitch do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/killswitch" }
  let(:status_body) { { dhanClientId: "1100003626", killSwitchStatus: "DEACTIVATE" }.to_json }

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#status" do
    it "GETs /v2/killswitch" do
      stub_request(:get, base)
        .to_return(status: 200, body: status_body, headers: { "Content-Type" => "application/json" })

      resource.status

      expect(WebMock).to have_requested(:get, base)
    end

    it "returns the kill switch status with indifferent access" do
      stub_request(:get, base)
        .to_return(status: 200, body: status_body, headers: { "Content-Type" => "application/json" })

      response = resource.status

      expect(response["killSwitchStatus"]).to eq("DEACTIVATE")
      expect(response[:dhanClientId]).to eq("1100003626")
    end
  end

  describe "#update" do
    it "POSTs to /v2/killswitch with the killSwitchStatus query parameter" do
      stub_request(:post, "#{base}?killSwitchStatus=ACTIVATE")
        .to_return(status: 200, body: status_body, headers: { "Content-Type" => "application/json" })

      resource.update("ACTIVATE")

      expect(WebMock).to have_requested(:post, "#{base}?killSwitchStatus=ACTIVATE")
    end

    it "normalizes lowercase input" do
      stub_request(:post, "#{base}?killSwitchStatus=DEACTIVATE")
        .to_return(status: 200, body: status_body, headers: { "Content-Type" => "application/json" })

      resource.update(" deactivate ")

      expect(WebMock).to have_requested(:post, "#{base}?killSwitchStatus=DEACTIVATE")
    end

    it "accepts symbols" do
      stub_request(:post, "#{base}?killSwitchStatus=ACTIVATE")
        .to_return(status: 200, body: status_body, headers: { "Content-Type" => "application/json" })

      resource.update(:activate)

      expect(WebMock).to have_requested(:post, "#{base}?killSwitchStatus=ACTIVATE")
    end

    it "raises ValidationError for an unknown status without hitting the API" do
      expect { resource.update("SOMETHING_ELSE") }
        .to raise_error(DhanHQ::ValidationError, /killSwitchStatus must be one of/)
    end

    it "raises InvalidAuthenticationError on 401" do
      stub_request(:post, "#{base}?killSwitchStatus=ACTIVATE").to_return(
        status: 401,
        body: { errorCode: "TT-401", errorMessage: "Token is invalid or expired." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.update("ACTIVATE") }.to raise_error(DhanHQ::InvalidAuthenticationError)
    end
  end
end
