# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Order do
  subject(:order_model) { described_class }

  let(:order_id) { "452501297117" }
  let(:valid_order_params) do
    {
      transaction_type: "BUY",
      exchange_segment: "NSE_FNO",
      product_type: "MARGIN",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: "43492",
      quantity: 125,
      price: 100.0
    }
  end

  let(:camelized_order_params) do
    {
      transactionType: "BUY",
      exchangeSegment: "NSE_FNO",
      productType: "MARGIN",
      orderType: "LIMIT",
      validity: "DAY",
      securityId: "43492",
      quantity: 125,
      price: 100.0,
      dhanClientId: "test_client_id"
    }
  end

  let(:order_response) do
    {
      dhanClientId: "1000000003",
      orderId: "452501297117",
      correlationId: "123abc678",
      orderStatus: "PENDING",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "MARKET",
      validity: "DAY",
      tradingSymbol: "",
      securityId: "11536",
      quantity: 5,
      disclosedQuantity: 0,
      price: 0.0,
      triggerPrice: 0.0,
      afterMarketOrder: false,
      boProfitValue: 0.0,
      boStopLossValue: 0.0,
      legName: nil,
      createTime: "2021-11-24 13:33:03",
      updateTime: "2021-11-24 13:33:03",
      exchangeTime: "2021-11-24 13:33:03",
      drvExpiryDate: nil,
      drvOptionType: nil,
      drvStrikePrice: 0.0,
      omsErrorCode: nil,
      omsErrorDescription: nil,
      algoId: "string",
      remainingQuantity: 5,
      averageTradedPrice: 0,
      filledQty: 0
    }
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
      config.client_id = "test_client_id"
    end

    stub_request(:post, "https://api.dhan.co/v2/orders")
      .with(
        body: camelized_order_params.merge("dhanClientId" => "testClientId").to_json,
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Access-Token" => "header.payload.signature",
          "Content-Type" => "application/json",
          "User-Agent" => "Faraday v1.10.4"
        }
      )
      .to_return(status: 200, body: { orderId: order_id, orderStatus: "TRANSIT" }.to_json)

    stub_request(:put, "https://api.dhan.co/v2/orders/#{order_id}")
      .with(
        body: { price: 105.0 }.to_json,
        headers: {
          "Accept" => "application/json",
          "Access-Token" => "header.payload.signature",
          "Content-Type" => "application/json"
        }
      )
      .to_return(status: 200, body: { orderId: order_id, orderStatus: "MODIFIED" }.to_json)

    stub_request(:delete, "https://api.dhan.co/v2/orders/#{order_id}")
      .to_return(status: 200, body: { orderId: order_id, orderStatus: "CANCELLED" }.to_json)

    stub_request(:get, "https://api.dhan.co/v2/orders/#{order_id}")
      .to_return(status: 200, body: order_response.to_json)

    stub_request(:get, "https://api.dhan.co/v2/orders")
      .to_return(status: 200, body: [{ orderId: order_id, orderStatus: "TRADED" }].to_json)
  end

  after { VCR.turn_on! }

  describe ".place" do
    it "places an order successfully" do
      order = order_model.place(valid_order_params)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq(order_id)
      expect(order.order_status).to eq("TRANSIT")
    end
  end

  describe ".find" do
    it "retrieves an order by ID" do
      order = order_model.find(order_id)

      expect(order).to be_a(described_class)
      expect(order.order_id).to eq(order_id)
      expect(order.order_status).to eq("TRADED")
    end
  end

  describe "#modify" do
    it "modifies an order successfully" do
      order = order_model.find(order_id)
      modified_order = order.modify(price: 105.0)

      expect(modified_order).to be_a(described_class)
      expect(modified_order.order_status).to eq("MODIFIED")
    end
  end

  describe "#cancel" do
    it "cancels an order successfully" do
      order = order_model.find(order_id)
      response = order.cancel

      expect(response).to be_truthy
    end
  end
end
