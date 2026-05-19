# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe DhanHQ::Models::Order do
  let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
  let(:order) do
    described_class.new(
      { orderId: "OID1", dhanClientId: "1100003626", quantity: 5, orderStatus: "PENDING" },
      skip_validation: true
    )
  end

  before do
    DhanHQ.configure_with_env
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe "#modify" do
    it "sends filtered camelized payload to resource update" do
      allow(resource_double).to receive(:update).and_return({ status: "success", orderStatus: "MODIFIED" })

      updated = order.modify(quantity: 2, ignored: nil)

      expect(resource_double).to have_received(:update).with(
        "OID1",
        hash_including("orderId" => "OID1", "dhanClientId" => "1100003626", "quantity" => 2)
      )
      expect(resource_double).to have_received(:update).with(
        anything, hash_excluding("orderStatus")
      )
      expect(updated.order_status).to eq("MODIFIED")
    end

    it "returns error object when update returns a failure response" do
      allow(resource_double).to receive(:update).and_return({ status: "error" })

      result = order.modify(quantity: 2)
      expect(result).to be_a(DhanHQ::ErrorObject)
    end

    it "logs a warning when modifying a TRADED order but still attempts the API call" do
      traded_order = described_class.new({ orderId: "OID1", orderStatus: "TRADED" }, skip_validation: true)
      allow(resource_double).to receive(:update).and_return({ errorMessage: "Order already traded" })
      allow(DhanHQ.logger).to receive(:warn)

      expect(traded_order.modify(quantity: 10)).to be_a(DhanHQ::ErrorObject)
      expect(DhanHQ.logger).to have_received(:warn).with(/Attempting to modify order.*TRADED state/)
    end

    it "logs a warning when modifying a CANCELLED order but still attempts the API call" do
      cancelled_order = described_class.new({ orderId: "OID1", orderStatus: "CANCELLED" }, skip_validation: true)
      allow(resource_double).to receive(:update).and_return({ errorMessage: "Order already cancelled" })
      allow(DhanHQ.logger).to receive(:warn)

      expect(cancelled_order.modify(quantity: 10)).to be_a(DhanHQ::ErrorObject)
      expect(DhanHQ.logger).to have_received(:warn).with(/Attempting to modify order.*CANCELLED state/)
    end

    it "allows modification of a PENDING order" do
      allow(resource_double).to receive(:update).and_return({ "status" => "success", "orderId" => "OID1" })
      expect(order.modify(quantity: 10)).to be(order)
    end

    it "omits trigger_price when 0 for non–stop-loss order (quantity-only modify passes validation and API gets clean payload)" do
      limit_order = described_class.new(
        {
          orderId: "OID1", dhanClientId: "1100003626", orderType: "LIMIT", orderStatus: "PENDING",
          transactionType: "BUY", exchangeSegment: "NSE_EQ", productType: "CNC", validity: "DAY",
          securityId: "1333", quantity: 10, price: 155.0, triggerPrice: 0.0
        },
        skip_validation: true
      )
      allow(resource_double).to receive(:update).and_return({ "status" => "success", "orderStatus" => "MODIFIED" })

      limit_order.modify(quantity: 20)

      expect(resource_double).to have_received(:update).with("OID1", hash_excluding("triggerPrice"))
      expect(resource_double).to have_received(:update).with("OID1", hash_including("quantity" => 20))
    end

    it "sends bo_profit_value and bo_stop_loss_value when modifying BO order" do
      bo_order = described_class.new(
        {
          orderId: "OID1", dhanClientId: "1100003626", orderType: "LIMIT", orderStatus: "PENDING",
          transactionType: "BUY", exchangeSegment: "NSE_EQ", productType: "BO", validity: "DAY",
          securityId: "1333", quantity: 10, price: 155.0,
          boProfitValue: 170.0, boStopLossValue: 140.0, legName: "ENTRY_LEG"
        },
        skip_validation: true
      )
      allow(resource_double).to receive(:update).and_return({ "status" => "success", "orderStatus" => "MODIFIED" })

      bo_order.modify(bo_profit_value: 172.0, bo_stop_loss_value: 138.0)

      expect(resource_double).to have_received(:update).with(
        "OID1",
        hash_including("boProfitValue" => 172.0, "boStopLossValue" => 138.0)
      )
    end

    context "when modification limit (25 per order) is reached" do
      it "raises ModificationLimitError before the 26th modify and does not call the API" do
        allow(resource_double).to receive(:update).and_return({ "status" => "success", "orderStatus" => "MODIFIED" })

        25.times { order.modify(quantity: 1) }
        expect(resource_double).to have_received(:update).exactly(25).times

        expect { order.modify(quantity: 2) }.to raise_error(DhanHQ::ModificationLimitError, /25 per order/)
        expect(resource_double).to have_received(:update).exactly(25).times
      end

      it "raises with a message including the limit" do
        allow(resource_double).to receive(:update).and_return({ "status" => "success", "orderStatus" => "MODIFIED" })
        25.times { order.modify(quantity: 1) }

        expect { order.modify(quantity: 1) }.to raise_error(DhanHQ::ModificationLimitError) do |e|
          expect(e.message).to include("25")
        end
      end
    end
  end

  describe "#save" do
    let(:new_order) { described_class.new({}, skip_validation: true) }

    before do
      allow(new_order).to receive(:assign_attributes)
      allow(new_order).to receive_messages(normalize_keys: { order_id: "OID1" }, to_request_params: {})
    end

    it "places a new order when valid and logs info" do
      allow(new_order).to receive_messages(valid?: true, new_record?: true)
      allow(resource_double).to receive(:create).and_return({ status: "success", "orderId" => "OID1" })
      allow(DhanHQ.logger).to receive(:info)

      expect(new_order.save).to be(true)
      expect(DhanHQ.logger).to have_received(:info).with(/Placing order/)
      expect(DhanHQ.logger).to have_received(:info).with(/Order placement successfully/)
    end

    it "returns false when create fails and logs error" do
      allow(new_order).to receive_messages(valid?: true, new_record?: true)
      allow(resource_double).to receive(:create).and_return({ errorMessage: "Insufficient funds" })
      allow(DhanHQ.logger).to receive(:info)
      allow(DhanHQ.logger).to receive(:error)

      expect(new_order.save).to be(false)
      expect(DhanHQ.logger).to have_received(:info).with(/Placing order/)
      expect(DhanHQ.logger).to have_received(:error).with(/Order placement failed/)
    end

    it "updates existing orders and logs modification" do
      allow(new_order).to receive_messages(valid?: true, new_record?: false, id: "OID1")
      allow(resource_double).to receive(:update).and_return({ status: "success", "orderStatus" => "MODIFIED" })
      allow(DhanHQ.logger).to receive(:info)

      expect(new_order.save).to be(true)
      expect(DhanHQ.logger).to have_received(:info).with(/Modifying order/)
      expect(DhanHQ.logger).to have_received(:info).with(/Order modification successfully/)
    end

    it "returns false when update fails and logs error" do
      allow(new_order).to receive_messages(valid?: true, new_record?: false, id: "OID1")
      allow(resource_double).to receive(:update).and_return({ errorMessage: "Order not found" })
      allow(DhanHQ.logger).to receive(:info)
      allow(DhanHQ.logger).to receive(:error)

      expect(new_order.save).to be(false)
      expect(DhanHQ.logger).to have_received(:info).with(/Modifying order/)
      expect(DhanHQ.logger).to have_received(:error).with(/Order modification failed/)
    end
  end

  describe "#refresh" do
    it "raises when order id is missing" do
      record = described_class.new({}, skip_validation: true)
      expect { record.refresh }.to raise_error("Order ID is required to refresh an order")
    end

    it "delegates to .find with the current order id" do
      record = described_class.new({ orderId: "OID1" }, skip_validation: true)
      allow(described_class).to receive(:find).with("OID1").and_return(:reloaded)

      expect(record.refresh).to eq(:reloaded)
      expect(described_class).to have_received(:find).with("OID1")
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
