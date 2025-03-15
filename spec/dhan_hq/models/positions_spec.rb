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
end
