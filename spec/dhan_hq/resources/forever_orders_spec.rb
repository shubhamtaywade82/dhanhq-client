# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::ForeverOrders do
  let(:forever_orders) { described_class.new }

  let(:valid_order_params) do
    {
      dhanClientId: "1000000132",
      correlationId: "correlation123",
      orderFlag: "SINGLE",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "CNC",
      orderType: "LIMIT",
      validity: "DAY",
      securityId: "1333",
      quantity: 5,
      disclosedQuantity: 1,
      price: 1428,
      triggerPrice: 1427
    }
  end

  let(:mock_order_response) do
    {
      orderId: "5132208051112",
      orderStatus: "PENDING"
    }.to_json
  end

  let(:mock_list_response) do
    [
      {
        dhanClientId: "1000000132",
        orderId: "1132208051115",
        orderStatus: "CONFIRM",
        transactionType: "BUY",
        exchangeSegment: "NSE_EQ",
        productType: "CNC",
        orderType: "SINGLE",
        tradingSymbol: "HDFCBANK",
        securityId: "1333",
        quantity: 10,
        price: 1428,
        triggerPrice: 1427,
        legName: "ENTRY_LEG",
        createTime: "2022-08-05 12:41:19",
        updateTime: nil,
        exchangeTime: nil,
        drvExpiryDate: nil,
        drvOptionType: nil,
        drvStrikePrice: 0
      }
    ].to_json
  end

  before do
    VCR.turn_off!
    stub_request(:post, "https://api.dhan.co/v2/forever/orders")
      .to_return(
        status: 200,
        body: mock_order_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:put, "https://api.dhan.co/v2/forever/orders/5132208051112")
      .to_return(
        status: 200,
        body: mock_order_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:delete, "https://api.dhan.co/v2/forever/orders/5132208051112")
      .to_return(
        status: 200,
        body: mock_order_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.dhan.co/v2/forever/orders")
      .to_return(
        status: 200,
        body: mock_list_response,
        headers: { "Content-Type" => "application/json" }
      )
  end

  after { VCR.turn_on! }

  describe "#create" do
    it "creates a new Forever Order successfully" do
      response = forever_orders.create(valid_order_params)
      expect(response["orderId"]).to eq("5132208051112")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#modify" do
    it "modifies an existing Forever Order successfully" do
      response = forever_orders.modify("5132208051112", { price: 1400 })
      expect(response["orderId"]).to eq("5132208051112")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#cancel" do
    it "cancels an existing Forever Order successfully" do
      response = forever_orders.cancel("5132208051112")
      expect(response["orderId"]).to eq("5132208051112")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#list" do
    it "retrieves all Forever Orders successfully" do
      response = forever_orders.list
      expect(response).to be_an(Array)
      expect(response.first["orderId"]).to eq("1132208051115")
      expect(response.first["orderStatus"]).to eq("CONFIRM")
    end
  end
end
