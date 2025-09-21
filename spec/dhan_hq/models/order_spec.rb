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
end
