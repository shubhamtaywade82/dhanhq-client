# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Holdings do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/holdings" }
  let(:holding) do
    {
      dhanClientId: "1100003626",
      securityId: "1333",
      exchangeSegment: "NSE_EQ",
      ISIN: "INE002A01018",
      tradingSymbol: "RELIANCE",
      quantity: 10,
      averagePrice: 2450.55
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#all" do
    it "GETs /v2/holdings" do
      stub_request(:get, base)
        .to_return(status: 200, body: [holding].to_json, headers: { "Content-Type" => "application/json" })

      resource.all

      expect(WebMock).to have_requested(:get, base)
    end

    it "returns holdings as an array with indifferent access" do
      stub_request(:get, base)
        .to_return(status: 200, body: [holding].to_json, headers: { "Content-Type" => "application/json" })

      response = resource.all

      expect(response).to be_an(Array)
      expect(response.first["securityId"]).to eq("1333")
      expect(response.first[:quantity]).to eq(10)
    end

    it "handles an empty holdings list" do
      stub_request(:get, base)
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(resource.all).to eq([])
    end

    it "raises NoHoldingsError with a friendly message when the API reports DH-1111" do
      stub_request(:get, base).to_return(
        status: 404,
        body: { errorCode: "DH-1111", errorMessage: "No Holdings Found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.all }.to raise_error(DhanHQ::NoHoldingsError, /No holdings found for this account/)
    end
  end
end
