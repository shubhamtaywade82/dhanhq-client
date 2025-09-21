# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Order do
  subject(:order_model) { described_class }

  let(:order_id) { "952502167319" }
  # Common test data
  let(:valid_order_params) do
    {
      correlationId: "correl-amo-#{Time.now.to_i}",
      transactionType: "BUY",
      exchangeSegment: "BSE_EQ",
      productType: "CNC",
      orderType: "MARKET",
      validity: "DAY",
      securityId: "539310",
      quantity: 5,
      disclosedQuantity: "",
      price: "", # Market order => no price needed
      triggerPrice: "",
      afterMarketOrder: true, # Key: AMO flag set to true
      amoTime: "OPEN", # This indicates it will be pumped at market open
      boProfitValue: "",
      boStopLossValue: ""
    }
  end

  # Updated order response after modification
  let(:updated_order_response) do
    initial_order_response.merge(
      orderStatus: "TRANSIT", # Simulate order modification
      price: 105.0 # Confirm price change
    )
  end

  before do
    DhanHQ.configure_with_env
  end

  describe ".all" do
    it "retrieves all orders for the day", vcr: "models/orders/all" do
      orders = order_model.all

      expect(orders).to be_a(Array)
      expect(orders.first).to be_a(described_class)
    end
  end

  describe ".create" do
    it "places a new order and returns an order instance", vcr: "models/orders/create" do
      order = described_class.create(valid_order_params)

      expect(order).to be_a(described_class)
      expect(order.order_id).not_to be_nil
      expect(order.order_status).to eq("PENDING").or eq("TRANSIT").or eq("REJECTED")
    end
  end

  # describe ".place" do
  #   it "places an order successfully" do
  #     order = order_model.place(valid_order_params)

  #     expect(order).to be_a(described_class)
  #     expect(order.order_id).to eq(order_id)
  #     expect(order.order_status).to eq("PENDING")
  #   end
  # end

  describe ".place" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
    let(:place_params) do
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
      allow(described_class).to receive(:resource).and_return(resource_double)
      allow(resource_double).to receive(:find).with("OID123")
                                              .and_return({ "orderId" => "OID123", "orderStatus" => "PENDING" })
    end

    it "validates, formats payload and delegates to resource create" do
      expect(resource_double).to receive(:create).with(
        hash_including(
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ",
          "productType" => "CNC",
          "orderType" => "MARKET",
          "validity" => "DAY",
          "securityId" => "1333",
          "quantity" => 1
        )
      ).and_return({ "orderId" => "OID123" })

      order = described_class.place(place_params)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq("OID123")
      expect(order.order_status).to eq("PENDING")
    end
  end

  describe ".find" do
    it "retrieves an order by ID", vcr: "models/orders/order" do
      order = order_model.find(order_id)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq(order_id)
      expect(order.order_status).to eq("PENDING")
    end
  end

  describe "#update" do
    it "modifies a pending order in the orderbook", vcr: "models/orders/update" do
      found_order = described_class.find(order_id)
      expect(found_order).to be_a(described_class),
                             "Expected an Order, got #{found_order.inspect}"

      #
      # 3. Update the order's quantity (and optionally price)
      #
      updated_quantity = 10
      updated_price    = "3400.0" # In case we switch to a 'LIMIT' for testing
      # If you keep 'MARKET' order_type, price may not matter. But let's assume it can be updated.
      update_attrs = {
        quantity: updated_quantity,
        price: updated_price
      }

      # updated_order = found_order.update(update_attrs)
      # # The #update method might return an Order or an ErrorObject
      # expect(updated_order).to be_a(described_class).or be_a(DhanHQ::ErrorObject)

      # if updated_order.is_a?(described_class)
      #   expect(updated_order.order_id).to eq(order_id)
      #   # You can also check that quantity is updated,
      #   # though the API might reflect partial changes or rejections
      #   expect(updated_order.quantity).to eq(updated_quantity),
      #                                     "Quantity expected to be #{updated_quantity}, but got #{updated_order.quantity}"
      # else
      #   warn "Order update failed: #{updated_order.message} / #{updated_order.errors}"
      # end
      found_order.attributes.merge!(update_attrs)

      expect do
        found_order.save
      end.to raise_error(DhanHQ::OrderError)
    end
  end

  # describe "#modify" do
  #   it "modifies an order successfully while retaining existing attributes" do
  #     order = order_model.find(order_id)

  #     # Ensure price update while keeping other fields unchanged
  #     modified_order = order.modify(price: 105.0)

  #     expect(modified_order).to be_a(described_class)
  #     expect(modified_order.order_status).to eq("TRANSIT")
  #     expect(modified_order.price).to eq(105.0) # Confirm price updated
  #     expect(modified_order.quantity).to eq(order.quantity) # Ensure quantity is unchanged
  #     expect(modified_order.security_id).to eq(order.security_id) # Security ID should remain the same
  #   end
  # end

  # describe "#cancel" do
  #   it "cancels an order successfully" do
  #     order = order_model.find(order_id)
  #     response = order.cancel

  #     expect(response).to be_truthy
  #   end
  # end

  describe "#cancel" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
    let(:order) { described_class.new({ orderId: "OID123" }, skip_validation: true) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "delegates to resource.cancel and returns true on success" do
      expect(resource_double).to receive(:cancel).with("OID123")
                                                .and_return({ "orderStatus" => "CANCELLED" })

      expect(order.cancel).to be(true)
    end
  end

  describe "#modify" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
    let(:order) do
      described_class.new(
        {
          orderId: "OID123",
          dhanClientId: "CID",
          quantity: 5,
          orderStatus: "PENDING",
          createTime: "2025-01-01T00:00:00"
        },
        skip_validation: true
      )
    end

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "validates payload, delegates to resource update and refreshes attributes" do
      expect(resource_double).to receive(:update) do |id, payload|
        expect(id).to eq("OID123")
        expect(payload).to include(
          "orderId" => "OID123",
          "dhanClientId" => "CID",
          "quantity" => 10
        )
        expect(payload).not_to have_key("orderStatus")
        expect(payload).not_to have_key("createTime")
        { "status" => "success", "orderId" => "OID123", "quantity" => 10 }
      end

      result = order.modify(quantity: 10)

      expect(result).to be(order)
      expect(order.quantity).to eq(10)
    end
  end

  describe "#slice_order" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }
    let(:order) do
      described_class.new({ orderId: "OID123", dhanClientId: "1100003626" }, skip_validation: true)
    end

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "camelizes, validates, and delegates to slicing" do
      params = {
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "CNC",
        order_type: "STOP_LOSS",
        validity: "DAY",
        security_id: "1333",
        quantity: 1,
        trigger_price: 1500.5
      }

      expect(resource_double).to receive(:slicing).with(
        hash_including(
          "orderId" => "OID123",
          "transactionType" => "BUY",
          "triggerPrice" => 1500.5
        )
      ).and_return([{ "orderStatus" => "PENDING" }])

      order.slice_order(params)
    end

    it "raises when trigger price missing for stop loss" do
      params = {
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "CNC",
        order_type: "STOP_LOSS",
        validity: "DAY",
        security_id: "1333",
        quantity: 1
      }

      expect do
        order.slice_order(params)
      end.to raise_error(DhanHQ::Error, /triggerPrice/)
    end
  end

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Orders) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    describe ".all" do
      it "wraps array responses" do
        allow(resource_double).to receive(:all).and_return([{ "orderId" => "OID1", "orderStatus" => "PENDING" }])

        orders = described_class.all
        expect(orders.map(&:order_id)).to eq(["OID1"])
      end

      it "returns [] for non array" do
        allow(resource_double).to receive(:all).and_return("unexpected")

        expect(described_class.all).to eq([])
      end
    end

    describe ".find" do
      it "unwraps array payloads" do
        allow(resource_double).to receive(:find).with("OID1").and_return([{ "orderId" => "OID1" }])

        order = described_class.find("OID1")
        expect(order.order_id).to eq("OID1")
      end
    end

    describe ".find_by_correlation" do
      it "returns model when status success" do
        allow(resource_double).to receive(:by_correlation).with("CORR")
                                                          .and_return({ status: "success", orderId: "OID1" })

        order = described_class.find_by_correlation("CORR")
        expect(order.order_id).to eq("OID1")
      end

      it "returns nil for non-success" do
        allow(resource_double).to receive(:by_correlation).and_return({ status: "error" })

        expect(described_class.find_by_correlation("CORR")).to be_nil
      end
    end

    describe ".place" do
      let(:params) do
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

      it "camelizes payload and fetches final order" do
        expect(resource_double).to receive(:create).with(hash_including(
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ"
        )).and_return({ "orderId" => "OID1" })
        expect(resource_double).to receive(:find).with("OID1")
                                                 .and_return({ "orderId" => "OID1", "orderStatus" => "PENDING" })

        order = described_class.place(params)
        expect(order.order_status).to eq("PENDING")
      end
    end

    describe "#modify" do
      let(:order) { described_class.new({ orderId: "OID1", dhanClientId: "1100003626" }, skip_validation: true) }

      it "sends filtered camelized payload" do
        expect(resource_double).to receive(:update).with("OID1", { "orderId" => "OID1", "dhanClientId" => "1100003626", "quantity" => 2 })
                                                   .and_return({ status: "success", orderStatus: "MODIFIED" })

        updated = order.modify(quantity: 2, ignored: nil)
        expect(updated.order_status).to eq("MODIFIED")
      end

      it "returns error object when update unsuccessful" do
        allow(resource_double).to receive(:update).and_return({ status: "error" })

        result = order.modify(quantity: 2)
        expect(result).to be_a(DhanHQ::ErrorObject)
      end
    end

    describe "#cancel" do
      let(:order) { described_class.new({ orderId: "OID1" }, skip_validation: true) }

      it "delegates to resource" do
        expect(resource_double).to receive(:cancel).with("OID1").and_return({ "orderStatus" => "CANCELLED" })
        expect(order.cancel).to be(true)
      end
    end

    describe "#refresh" do
      it "raises when order id missing" do
        record = described_class.new({}, skip_validation: true)
        expect { record.refresh }.to raise_error("Order ID is required to refresh an order")
      end

      it "delegates to find" do
        record = described_class.new({ orderId: "OID1" }, skip_validation: true)
        expect(described_class).to receive(:find).with("OID1").and_return(:reloaded)

        expect(record.refresh).to eq(:reloaded)
      end
    end

    describe "#save" do
      let(:order) { described_class.new({}, skip_validation: true) }

      before do
        allow(order).to receive(:assign_attributes)
        allow(order).to receive(:normalize_keys).and_return({ order_id: "OID1" })
        allow(order).to receive(:to_request_params).and_return({})
      end

      it "places a new order when valid" do
        allow(order).to receive(:valid?).and_return(true)
        allow(order).to receive(:new_record?).and_return(true)
        expect(resource_double).to receive(:create).and_return({ status: "success", "orderId" => "OID1" })

        expect(order.save).to be(true)
      end

      it "returns false when create fails" do
        allow(order).to receive(:valid?).and_return(true)
        allow(order).to receive(:new_record?).and_return(true)
        expect(resource_double).to receive(:create).and_return({})

        expect(order.save).to be(false)
      end

      it "updates existing orders" do
        allow(order).to receive(:valid?).and_return(true)
        allow(order).to receive(:new_record?).and_return(false)
        allow(order).to receive(:id).and_return("OID1")
        expect(resource_double).to receive(:update).and_return({ status: "success", "orderStatus" => "MODIFIED" })

        expect(order.save).to be(true)
      end

      it "returns false when update fails" do
        allow(order).to receive(:valid?).and_return(true)
        allow(order).to receive(:new_record?).and_return(false)
        allow(order).to receive(:id).and_return("OID1")
        expect(resource_double).to receive(:update).and_return({})

        expect(order.save).to be(false)
      end
    end

    describe "#destroy" do
      it "returns false for new records" do
        record = described_class.new({}, skip_validation: true)
        expect(record.destroy).to be(false)
      end

      it "returns true when deletion succeeds" do
        record = described_class.new({ orderId: "OID1" }, skip_validation: true)
        expect(resource_double).to receive(:delete).with("OID1").and_return({ status: "success", "orderStatus" => "CANCELLED" })

        expect(record.destroy).to be(true)
      end

      it "returns false when deletion fails" do
        record = described_class.new({ orderId: "OID1" }, skip_validation: true)
        expect(resource_double).to receive(:delete).and_return({ "orderStatus" => "ACTIVE" })

        expect(record.destroy).to be(false)
      end
    end
  end
end
