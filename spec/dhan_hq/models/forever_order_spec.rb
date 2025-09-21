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
    it "returns nil when the API does not return an orderId" do
      allow(resource_double).to receive(:create).and_return({ "status" => "fail" })

      expect(described_class.create({})).to be_nil
    end

    it "fetches the created order when orderId is present" do
      allow(resource_double).to receive(:create).and_return({ "orderId" => "OID-1" })
      allow(resource_double).to receive(:find).with("OID-1").and_return({ "orderId" => "OID-1" })

      record = described_class.create({})
      expect(record).to be_a(described_class)
      expect(record.order_id).to eq("OID-1")
    end
  end

  describe "#modify" do
    let(:order) { described_class.new({ orderId: "OID-1" }, skip_validation: true) }

    it "raises when order_id is missing" do
      record = described_class.new({}, skip_validation: true)

      expect { record.modify({}) }.to raise_error("Order ID is required to modify a forever order")
    end

    it "returns updated record when the response is successful" do
      allow(resource_double).to receive(:update).with("OID-1", { price: 100 })
                                                .and_return({ status: "success" })
      allow(resource_double).to receive(:find).with("OID-1").and_return({ "orderId" => "OID-1", "price" => 100 })

      updated = order.modify(price: 100)
      expect(updated).to be_a(described_class)
      expect(updated.price).to eq(100)
    end

    it "returns nil when the response is not successful" do
      allow(resource_double).to receive(:update).and_return({ status: "rejected" })

      expect(order.modify(price: 100)).to be_nil
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

