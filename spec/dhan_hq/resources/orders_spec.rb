# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Orders do
  let(:orders) { described_class.new }

  let(:valid_order_params) do
    {
      dhanClientId: "1000000003",
      correlationId: "123abc678",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "MARKET",
      validity: "DAY",
      securityId: "11536",
      quantity: 5,
      price: 100.0
    }
  end

  let(:mock_order_response) do
    {
      orderId: "112111182198",
      orderStatus: "PENDING"
    }.to_json
  end

  let(:mock_slice_response) do
    [
      { orderId: "552209237100", orderStatus: "TRANSIT" },
      { orderId: "552209237101", orderStatus: "TRANSIT" }
    ].to_json
  end

  let(:mock_list_response) do
    [
      {
        "dhanClientId" => "1000000003",
        "orderId" => "112111182198",
        "correlationId" => "123abc678",
        "orderStatus" => "PENDING",
        "transactionType" => "BUY",
        "exchangeSegment" => "NSE_EQ",
        "productType" => "INTRADAY",
        "orderType" => "MARKET",
        "validity" => "DAY",
        "tradingSymbol" => "",
        "securityId" => "11536",
        "quantity" => 5,
        "disclosedQuantity" => 0,
        "price" => 0.0,
        "triggerPrice" => 0.0,
        "afterMarketOrder" => false,
        "boProfitValue" => 0.0,
        "boStopLossValue" => 0.0,
        "legName" => nil,
        "createTime" => "2021-11-24 13:33:03",
        "updateTime" => "2021-11-24 13:33:03",
        "exchangeTime" => "2021-11-24 13:33:03",
        "drvExpiryDate" => nil,
        "drvOptionType" => nil,
        "drvStrikePrice" => 0.0,
        "omsErrorCode" => nil,
        "omsErrorDescription" => nil,
        "algoId" => "string",
        "remainingQuantity" => 5,
        "averageTradedPrice" => 0,
        "filledQty" => 0
      }
    ].to_json
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
      config.client_id = "test_client_id"
    end

    # # Mock client responses for all HTTP requests
    # allow_any_instance_of(DhanHQ::Client).to receive(:post).and_return(mock_response)
    # allow_any_instance_of(DhanHQ::Client).to receive(:put).and_return(mock_response)
    # allow_any_instance_of(DhanHQ::Client).to receive(:delete).and_return(mock_response)
    # allow_any_instance_of(DhanHQ::Client).to receive(:get).and_return(mock_list_response)
  end

  after { VCR.turn_on! }

  describe "#place_order" do
    it "places a new order successfully" do
      stub_request(:post, "https://api.dhan.co/v2/orders")
        .with(
          body: valid_order_params.to_json,
          headers: {
            "Content-Type" => "application/json",
            "Access-Token" => "header.payload.signature"
          }
        )
        .to_return(
          status: 200,
          body: mock_order_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.place_order(valid_order_params)
      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#modify_order" do
    it "modifies a pending order successfully" do
      stub_request(:put, "https://api.dhan.co/v2/orders/112111182198")
        .to_return(
          status: 200,
          body: mock_order_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.modify_order("112111182198", { price: 150.0 })
      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#cancel_order" do
    it "cancels a pending order successfully" do
      stub_request(:delete, "https://api.dhan.co/v2/orders/112111182198")
        .to_return(
          status: 200,
          body: mock_order_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.cancel_order("112111182198")
      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#slice_order" do
    it "slices an order into multiple legs successfully" do
      stub_request(:post, "https://api.dhan.co/v2/orders/slicing")
        .to_return(
          status: 200,
          body: mock_slice_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.slice_order(valid_order_params)
      expect(response).to be_an(Array)
      expect(response.first["orderId"]).to eq("552209237100")
    end
  end

  describe "#list_orders" do
    it "retrieves the list of all orders for the day" do
      stub_request(:get, "https://api.dhan.co/v2/orders")
        .to_return(
          status: 200,
          body: mock_list_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.list_orders
      expect(response).to be_an(Array)
      expect(response.first["orderId"]).to eq("112111182198")
    end
  end

  describe "#get_order" do
    it "retrieves the status of an order by order ID" do
      stub_request(:get, "https://api.dhan.co/v2/orders/112111182198")
        .to_return(
          status: 200,
          body: mock_order_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.get_order("112111182198")
      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end

  describe "#get_order_by_correlation" do
    it "retrieves the status of an order by correlation ID" do
      stub_request(:get, "https://api.dhan.co/v2/orders/external/123abc678")
        .to_return(
          status: 200,
          body: mock_order_response,
          headers: { "Content-Type" => "application/json" }
        )

      response = orders.get_order_by_correlation("123abc678")
      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("PENDING")
    end
  end
end
