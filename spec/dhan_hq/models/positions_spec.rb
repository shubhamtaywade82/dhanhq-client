# frozen_string_literal: true

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
      allow(resource_double).to receive(:convert).with(hash_including(
                                                         "dhanClientId" => "1100003626",
                                                         "convertQty" => 1
                                                       )).and_return({ status: "success" })

      expect(described_class.convert(params)).to eq({ status: "success" })
      expect(resource_double).to have_received(:convert).with(hash_including(
                                                                "dhanClientId" => "1100003626",
                                                                "convertQty" => 1
                                                              ))
    end

    it "wraps failures in an error object" do
      allow(resource_double).to receive(:convert).and_return({})

      expect(described_class.convert(params)).to be_a(DhanHQ::ErrorObject)
    end
  end
end
