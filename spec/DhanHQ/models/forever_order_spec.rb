# frozen_string_literal: true

RSpec.describe DhanHQ::Models::ForeverOrder do
  let(:resource_double) { instance_double(DhanHQ::Resources::ForeverOrders) }

  before do
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".all" do
    it "returns model instances when the response is an array" do
      allow(resource_double).to receive(:all).and_return([{ "orderId" => "OID-1" }])

      result = described_class.all

      expect(result).to all(be_a(described_class))
      expect(result.first.order_id).to eq("OID-1")
    end

    it "returns an empty array when the response is not an array" do
      allow(resource_double).to receive(:all).and_return("unexpected")

      expect(described_class.all).to eq([])
    end
  end

  describe ".find" do
    it "returns nil when the response is blank" do
      allow(resource_double).to receive(:find).with("OID-1").and_return({})

      expect(described_class.find("OID-1")).to be_nil
    end

    it "wraps the response in a model" do
      allow(resource_double).to receive(:find).with("OID-1").and_return({ "orderId" => "OID-1" })

      record = described_class.find("OID-1")
      expect(record).to be_a(described_class)
      expect(record.order_id).to eq("OID-1")
    end
  end

  describe ".create" do
    let(:minimal_create_params) do
      {
        dhan_client_id: "1000000132",
        order_flag: "SINGLE",
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "CNC",
        order_type: "LIMIT",
        validity: "DAY",
        security_id: "1333",
        quantity: 5,
        price: 1428.0,
        trigger_price: 1427.0
      }
    end

    it "returns nil when the API does not return an orderId" do
      allow(resource_double).to receive(:create).and_return({ "status" => "fail" })

      expect(described_class.create(minimal_create_params)).to be_nil
    end

    it "fetches the created order when orderId is present" do
      allow(resource_double).to receive(:create).and_return({ "orderId" => "OID-1" })
      allow(resource_double).to receive(:find).with("OID-1").and_return({ "orderId" => "OID-1" })

      record = described_class.create(minimal_create_params)
      expect(record).to be_a(described_class)
      expect(record.order_id).to eq("OID-1")
    end
  end

  describe "#modify" do
    let(:order) { described_class.new({ "orderId" => "OID-1" }, skip_validation: true) }
    let(:modify_params) do
      {
        order_flag: "SINGLE",
        order_type: "LIMIT",
        leg_name: "TARGET_LEG",
        quantity: 15,
        price: 1421.0,
        trigger_price: 1420.0,
        validity: "DAY"
      }
    end

    it "raises when order_id is missing" do
      record = described_class.new({}, skip_validation: true)

      expect { record.modify({}) }.to raise_error("Order ID is required to modify a forever order")
    end

    it "returns updated record when the response is successful" do
      allow(resource_double).to receive(:update).with("OID-1", anything)
                                                .and_return({ "status" => "success" })
      allow(resource_double).to receive(:find).with("OID-1").and_return({ "orderId" => "OID-1", "price" => 1421.0 })

      updated = order.modify(modify_params)
      expect(updated).to be_a(described_class)
      expect(updated.price).to eq(1421.0)
    end

    it "returns nil when the response is not successful" do
      allow(resource_double).to receive(:update).and_return({ "status" => "rejected" })

      expect(order.modify(modify_params)).to be_nil
    end
  end

  describe "#cancel" do
    let(:order) { described_class.new({ orderId: "OID-1" }, skip_validation: true) }

    it "raises when order_id missing" do
      record = described_class.new({}, skip_validation: true)
      expect { record.cancel }.to raise_error("Order ID is required to cancel a forever order")
    end

    it "returns true when cancellation succeeds" do
      allow(resource_double).to receive(:cancel).with("OID-1").and_return({ "orderStatus" => "CANCELLED" })

      expect(order.cancel).to be(true)
    end

    it "returns false when cancellation fails" do
      allow(resource_double).to receive(:cancel).with("OID-1").and_return({ "orderStatus" => "ACTIVE" })

      expect(order.cancel).to be(false)
    end
  end
end
