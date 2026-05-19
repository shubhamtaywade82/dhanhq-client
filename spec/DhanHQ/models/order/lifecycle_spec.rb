# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe DhanHQ::Models::Order do
  let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }

  before do
    DhanHQ.configure_with_env
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe "#cancel" do
    let(:order) { described_class.new({ orderId: "OID1" }, skip_validation: true) }

    it "delegates to resource.cancel and returns true on success" do
      allow(resource_double).to receive(:cancel).with("OID1")
                                                .and_return({ "orderStatus" => "CANCELLED" })

      expect(order.cancel).to be(true)
      expect(resource_double).to have_received(:cancel).with("OID1")
    end

    it "returns false when the order status is not CANCELLED" do
      allow(resource_double).to receive(:cancel).and_return({ "orderStatus" => "PENDING" })
      expect(order.cancel).to be(false)
    end
  end

  describe "#slice_order" do
    let(:order) { described_class.new({ orderId: "OID1", dhanClientId: "1100003626" }, skip_validation: true) }
    let(:base_slice_params) do
      {
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "CNC",
        order_type: "STOP_LOSS",
        validity: "DAY",
        security_id: "1333",
        quantity: 1,
        trigger_price: 1500.5
      }
    end

    it "camelizes, validates, and delegates to resource slicing" do
      allow(resource_double).to receive(:slicing).and_return([{ "orderStatus" => "PENDING" }])

      order.slice_order(base_slice_params)

      expect(resource_double).to have_received(:slicing).with(
        hash_including(
          "orderId" => "OID1",
          "transactionType" => "BUY",
          "triggerPrice" => 1500.5
        )
      )
    end

    it "raises a validation error when trigger price is missing for STOP_LOSS" do
      params = base_slice_params.except(:trigger_price)

      expect do
        order.slice_order(params)
      end.to raise_error(DhanHQ::Error, /triggerPrice/)
    end
  end

  describe "#destroy" do
    it "returns false for new (unsaved) records" do
      record = described_class.new({}, skip_validation: true)
      expect(record.destroy).to be(false)
    end

    it "returns true when the API confirms cancellation" do
      record = described_class.new({ orderId: "OID1" }, skip_validation: true)
      allow(resource_double).to receive(:delete).with("OID1")
                                                .and_return({ status: "success", "orderStatus" => "CANCELLED" })

      expect(record.destroy).to be(true)
      expect(resource_double).to have_received(:delete).with("OID1")
    end

    it "returns false when deletion does not result in CANCELLED status" do
      record = described_class.new({ orderId: "OID1" }, skip_validation: true)
      allow(resource_double).to receive(:delete).and_return({ "orderStatus" => "ACTIVE" })

      expect(record.destroy).to be(false)
    end

    it "#delete is an alias for #destroy" do
      record = described_class.new({ orderId: "OID1" }, skip_validation: true)
      allow(resource_double).to receive(:delete).with("OID1")
                                                .and_return({ status: "success", "orderStatus" => "CANCELLED" })

      expect(record.delete).to be(true)
      expect(resource_double).to have_received(:delete).with("OID1")
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
