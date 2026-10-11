# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::ExpiredOptionsData do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/charts/rollingoption" }
  let(:rolling_body) do
    {
      open: [120.5, 118.2],
      high: [125.0, 121.4],
      low: [118.0, 112.9],
      close: [119.7, 114.3],
      volume: [54_321, 43_210],
      timestamp: [1_737_974_400, 1_738_060_800]
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#fetch" do
    it "POSTs camelized params to /v2/charts/rollingoption" do
      stub_request(:post, base)
        .to_return(status: 200, body: rolling_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.fetch(
        security_id: "43826", exchange_segment: "NSE_FNO", instrument: "OPTIDX",
        expiry: "2025-01-30", strike_price: 23_000, option_type: "CE"
      )

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body).values_at("securityId", "expiry", "strikePrice", "optionType") ==
          ["43826", "2025-01-30", 23_000, "CE"]
      end)
    end

    it "injects dhanClientId into the body and client-id header" do
      stub_request(:post, base)
        .to_return(status: 200, body: rolling_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.fetch(security_id: "43826", exchange_segment: "NSE_FNO", instrument: "OPTIDX", expiry: "2025-01-30")

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body)["dhanClientId"] == "test_client_id"
      end)
      expect(WebMock).to have_requested(:post, base)
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "returns expired option candles with indifferent access" do
      stub_request(:post, base)
        .to_return(status: 200, body: rolling_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.fetch(security_id: "43826", exchange_segment: "NSE_FNO", instrument: "OPTIDX", expiry: "2025-01-30")

      expect(response["close"]).to eq([119.7, 114.3])
      expect(response[:volume]).to eq([54_321, 43_210])
    end

    it "raises InvalidRequestError when the expiry date is invalid (811)" do
      stub_request(:post, base).to_return(
        status: 400,
        body: { errorCode: 811, errorMessage: "Invalid Expiry Date" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect do
        resource.fetch(security_id: "43826", exchange_segment: "NSE_FNO", instrument: "OPTIDX", expiry: "bad-date")
      end.to raise_error(DhanHQ::InvalidRequestError)
    end
  end
end
