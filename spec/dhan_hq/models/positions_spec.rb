# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Positions, vcr: {
  cassette_name: "resources/positions", # name of your VCR cassette
  record: :once
} do
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
    it "fetches all open positions for the day" do
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

  describe "::convert" do
    it "converts a position via model", vcr: { cassette_name: "models/position_convert" } do
      result = DhanHQ::Models::Position.convert(conversion_params)

      expect(result).to be_a(Hash).or be_a(DhanHQ::ErrorObject)
    end
  end
end

RSpec.describe DhanHQ::Models::Position do
  let(:resource_double) { instance_double(DhanHQ::Resources::Positions) }

  before do
    described_class.instance_variable_set(:@resource, nil)
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".all" do
    it "wraps array responses" do
      allow(resource_double).to receive(:all).and_return([{ "positionType" => "LONG", "securityId" => "1333" }])

      result = described_class.all

      expect(result).to all(be_a(described_class))
      expect(result.first.position_type).to eq("LONG")
    end

    it "returns [] when response not array" do
      allow(resource_double).to receive(:all).and_return("unexpected")

      expect(described_class.all).to eq([])
    end
  end

  describe ".active" do
    it "filters closed positions" do
      allow(resource_double).to receive(:all).and_return([
                                                           { "positionType" => "LONG" },
                                                           { "positionType" => "CLOSED" }
                                                         ])

      expect(described_class.active.map(&:position_type)).to eq(["LONG"])
    end
  end

  describe ".convert" do
    let(:params) do
      {
        dhan_client_id: "1100003626",
        exchange_segment: "NSE_EQ",
        position_type: "LONG",
        security_id: "1333",
        convert_qty: 1,
        from_product_type: "INTRADAY",
        to_product_type: "CNC"
      }
    end

    it "returns the API response when successful" do
      expect(resource_double).to receive(:convert).with(hash_including(
                                                          "dhanClientId" => "1100003626",
                                                          "convertQty" => 1
                                                        )).and_return({ status: "success" })

      expect(described_class.convert(params)).to eq({ status: "success" })
    end

    it "wraps failures in an error object" do
      allow(resource_double).to receive(:convert).and_return({})

      expect(described_class.convert(params)).to be_a(DhanHQ::ErrorObject)
    end
  end
end
