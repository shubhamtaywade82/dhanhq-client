# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe DhanHQ::Models::Order do
  let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
  let(:base_params) do
    {
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "CNC",
      order_type: "MARKET",
      validity: "DAY",
      security_id: "1333",
      quantity: 1
    }
  end

  before do
    DhanHQ.configure_with_env
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".place" do
    it "validates, camelizes payload and delegates to resource create" do # rubocop:disable RSpec/ExampleLength
      allow(resource_double).to receive(:create).and_return({ "orderId" => "OID1" })
      allow(resource_double).to receive(:find).with("OID1")
                                              .and_return({ "orderId" => "OID1", "orderStatus" => "PENDING" })

      order = described_class.place(base_params)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq("OID1")
      expect(order.order_status).to eq("PENDING")
      expect(resource_double).to have_received(:create).with(
        hash_including(
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ",
          "productType" => "CNC",
          "orderType" => "MARKET",
          "validity" => "DAY",
          "securityId" => "1333",
          "quantity" => 1
        )
      )
      expect(resource_double).to have_received(:find).with("OID1")
    end

    it "returns nil when resource create does not return an orderId" do
      allow(resource_double).to receive(:create).and_return({ "errorMessage" => "rejected" })

      expect(described_class.place(base_params)).to be_nil
    end
  end

  describe ".find_by_correlation" do
    it "returns model when status is success" do
      allow(resource_double).to receive(:by_correlation).with("CORR")
                                                        .and_return({ status: "success", orderId: "OID1" })

      order = described_class.find_by_correlation("CORR")
      expect(order.order_id).to eq("OID1")
    end

    it "returns nil for non-success response" do
      allow(resource_double).to receive(:by_correlation).and_return({ status: "error" })

      expect(described_class.find_by_correlation("CORR")).to be_nil
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
