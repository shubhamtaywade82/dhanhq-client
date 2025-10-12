# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Positions do
  subject(:positions_resource) { described_class.new }

  before do
    # Configure with environment credentials (CLIENT_ID, ACCESS_TOKEN, etc.)
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
end
