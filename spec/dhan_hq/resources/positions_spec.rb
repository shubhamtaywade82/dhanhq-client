# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Positions do
  subject(:positions_resource) { described_class.new }

  before do
    # Configure with environment credentials (DHAN_CLIENT_ID, DHAN_ACCESS_TOKEN, etc.)
    DhanHQ.configure_with_env
  end

  let(:conversion_params) do
    {
      dhan_client_id: "1100003626",
      from_product_type: "INTRADAY",
      exchange_segment: "NSE_EQ",
      position_type: "LONG",
      security_id: "1333",
      convert_qty: 1,
      to_product_type: "CNC"
    }
  end

  describe "#all" do
    it "fetches all open positions for the day", vcr: { cassette_name: "resources/positions" } do
      response = positions_resource.all

      # The Positions resource returns an Array<Hash> if the request is successful
      expect(response).to be_an(Array)

      if response.any?
        position = response.first
        # Check it's a Hash with expected keys
        expect(position).to be_a(Hash)
        # For example, the docs mention fields like securityId, exchangeSegment, productType, netQty, etc.
        # Adjust the keys to match your actual response structure:
        expect(position).to include(
          "securityId",
          "exchangeSegment",
          "productType",
          "netQty" # or 'net_qty' if the API returns snake_case
        )
      else
        # If no positions exist, that's still a valid scenario
        # (the array can be empty). You can test that code path here.
        expect(response.size).to eq(0)
      end
    end
  end

  describe "#convert" do
    it "converts an existing position", vcr: { cassette_name: "resources/positions_convert" } do
      response = positions_resource.convert(conversion_params)

      expect(response).to be_a(Hash)
    end
  end

  describe "model integration" do
    it "converts a position via model", vcr: { cassette_name: "models/position_convert" } do
      result = DhanHQ::Models::Position.convert(conversion_params)

      expect(result).to be_a(Hash).or be_a(DhanHQ::ErrorObject)
    end
  end

  describe "request wire format" do
    subject(:positions_resource) { described_class.new }

    let(:base) { "https://api.dhan.co/v2/positions" }

    before do
      ENV["DHAN_CLIENT_ID"] = "test_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "GETs /v2/positions and returns them with indifferent access" do
      position = { securityId: "1333", exchangeSegment: "NSE_EQ", productType: "INTRADAY", netQty: 10 }
      stub_request(:get, base)
        .to_return(status: 200, body: [position].to_json, headers: { "Content-Type" => "application/json" })

      response = positions_resource.all

      expect(WebMock).to have_requested(:get, base)
      expect(response.first["securityId"]).to eq("1333")
      expect(response.first[:netQty]).to eq(10)
    end

    it "POSTs camelized params and injects dhanClientId to /v2/positions/convert" do
      stub_request(:post, "#{base}/convert")
        .to_return(status: 200, body: { orderId: "112025000000001", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      positions_resource.convert(conversion_params)

      expect(WebMock).to(have_requested(:post, "#{base}/convert").with do |req|
        parsed = JSON.parse(req.body)
        parsed.values_at("securityId", "fromProductType", "toProductType", "convertQty", "dhanClientId") ==
          ["1333", "INTRADAY", "CNC", 1, "1100003626"]
      end)
    end

    it "DELETEs /v2/positions for exit-all" do
      stub_request(:delete, base)
        .to_return(status: 202, body: "", headers: { "Content-Type" => "application/json" })

      response = positions_resource.exit_all

      expect(WebMock).to have_requested(:delete, base)
      expect(response).to eq({ "status" => "accepted" })
    end

    it "raises InputExceptionError when the conversion is rejected" do
      stub_request(:post, "#{base}/convert").to_return(
        status: 400,
        body: { errorCode: "DH-905", errorMessage: "Position conversion failed" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { positions_resource.convert(conversion_params) }.to raise_error(DhanHQ::InputExceptionError)
    end
  end
end
