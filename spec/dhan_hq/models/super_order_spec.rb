# frozen_string_literal: true

RSpec.describe DhanHQ::Models::SuperOrder do
  let(:resource_double) { instance_double(DhanHQ::Resources::SuperOrders) }

  before do
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".all" do
    it "returns model instances when response is array" do
      allow(resource_double).to receive(:all).and_return([{ "orderId" => "OID-1" }])

      result = described_class.all

      expect(result).to all(be_a(described_class))
      expect(result.first.order_id).to eq("OID-1")
    end

    it "returns [] for non-array responses" do
      allow(resource_double).to receive(:all).and_return("oops")

      expect(described_class.all).to eq([])
    end
  end

  describe ".create" do
    it "returns nil when orderId missing" do
      allow(resource_double).to receive(:create).and_return({ "status" => "fail" })

      expect(described_class.create({})).to be_nil
    end

    it "returns model with id and status when orderId present" do
      allow(resource_double).to receive(:create).and_return({ "orderId" => "OID-1", "orderStatus" => "PENDING" })
      dummy = double(order_id: "OID-1", order_status: "PENDING")
      allow(described_class).to receive(:new).with(order_id: "OID-1", order_status: "PENDING",
                                                   skip_validation: true)
                                             .and_return(dummy)

      record = described_class.create({})
      expect(record.order_id).to eq("OID-1")
      expect(record.order_status).to eq("PENDING")
    end
  end

  describe "#modify" do
    let(:order) { described_class.new({ orderId: "OID-1" }, skip_validation: true) }

    it "raises when order id missing" do
      record = described_class.new({}, skip_validation: true)

      expect { record.modify({}) }.to raise_error("Order ID is required to modify a super order")
    end

    it "returns true when update echoes orderId" do
      allow(resource_double).to receive(:update).with("OID-1", { price: 100 }).and_return({ "orderId" => "OID-1" })

      expect(order.modify(price: 100)).to be(true)
      expect(resource_double).to have_received(:update).with("OID-1", { price: 100 })
    end

    it "returns false otherwise" do
      allow(resource_double).to receive(:update).and_return({ "orderId" => "OTHER" })

      expect(order.modify(price: 100)).to be(false)
    end
  end

  describe "#cancel" do
    let(:order) { described_class.new({ orderId: "OID-1" }, skip_validation: true) }

    it "raises when order id missing" do
      record = described_class.new({}, skip_validation: true)

      expect { record.cancel }.to raise_error("Order ID is required to cancel a super order")
    end

    it "returns true when cancellation state is CANCELLED" do
      allow(resource_double).to receive(:cancel).with("OID-1", "ENTRY_LEG").and_return({ "orderStatus" => "CANCELLED" })

      expect(order.cancel).to be(true)
    end

    it "passes leg name and returns false otherwise" do
      allow(resource_double).to receive(:cancel).with("OID-1", "TARGET_LEG").and_return({ "orderStatus" => "ACTIVE" })

      expect(order.cancel("TARGET_LEG")).to be(false)
    end
  end
end
