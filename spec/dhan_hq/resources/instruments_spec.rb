# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Instruments do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/instrument" }
  let(:csv) do
    <<~CSV
      SERIES,SYMBOL,NAME OF THE COMPANY,IDENTIFIER,INSTRUMENT,FACE VALUE,ISIN
      EQ,RELIANCE,Reliance Industries Limited,INE002A01018,EQUITY,10,INE002A01018
    CSV
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#by_segment" do
    it "GETs /v2/instrument/{segment} and returns the CSV body" do
      stub_request(:get, "#{base}/NSE_EQ")
        .to_return(status: 200, body: csv, headers: { "Content-Type" => "text/csv" })

      response = resource.by_segment("NSE_EQ")

      expect(WebMock).to have_requested(:get, "#{base}/NSE_EQ")
      expect(response).to include("RELIANCE")
    end

    it "follows the 302 redirect to the CSV host and returns its body" do
      stub_request(:get, "#{base}/NSE_EQ").to_return(
        status: 302, headers: { "Location" => "https://s3.example.com/instruments/NSE_EQ.csv" }
      )
      stub_request(:get, "https://s3.example.com/instruments/NSE_EQ.csv")
        .to_return(status: 200, body: csv, headers: { "Content-Type" => "text/csv" })

      response = resource.by_segment("NSE_EQ")

      expect(WebMock).to have_requested(:get, "https://s3.example.com/instruments/NSE_EQ.csv")
      expect(response).to include("RELIANCE")
    end

    it "raises NotFoundError when the segment does not exist" do
      stub_request(:get, "#{base}/BAD_SEGMENT").to_return(
        status: 404,
        body: { errorCode: "TT-404", errorMessage: "Segment not found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.by_segment("BAD_SEGMENT") }.to raise_error(DhanHQ::NotFoundError)
    end

    it "raises InvalidAuthenticationError when the token is rejected" do
      stub_request(:get, "#{base}/NSE_EQ").to_return(
        status: 401,
        body: { errorCode: "TT-401", errorMessage: "Token is invalid or expired." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.by_segment("NSE_EQ") }.to raise_error(DhanHQ::InvalidAuthenticationError)
    end
  end
end
