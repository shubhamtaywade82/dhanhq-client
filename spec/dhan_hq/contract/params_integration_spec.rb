# frozen_string_literal: true

RSpec.describe "generated param structs through the resource layer" do
  subject(:resource) { DhanHQ::Resources::Orders.new }

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))

    # Stub IP lookups so tests never hit real network
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    stub_request(:get, "https://api-dhanhq.ipify.org").to_return(body: "1.2.3.4")

    # Risk checks resolve instruments; keep them offline
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  let(:struct) do
    DhanHQ::Contract::Params::OrderParams.new(
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "CNC",
      order_type: "LIMIT",
      security_id: "11536",
      quantity: 5,
      price: 195.5,
      validity: "DAY"
    )
  end

  it "places an order from a struct and camelizes the wire body correctly" do
    stub = stub_request(:post, %r{/v2/orders\z}).with do |request|
      body = JSON.parse(request.body)
      body.slice("transactionType", "exchangeSegment", "productType", "orderType",
                 "securityId", "quantity", "price", "validity", "dhanClientId") ==
        {
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ",
          "productType" => "CNC",
          "orderType" => "LIMIT",
          "securityId" => "11536",
          "quantity" => 5,
          "price" => 195.5,
          "validity" => "DAY",
          "dhanClientId" => DhanHQ.configuration.client_id
        }
    end.to_return(
      status: 200,
      body: { orderId: "ORD001", orderStatus: "PENDING" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    response = resource.create(struct)

    expect(stub).to have_been_requested
    expect(response["orderId"]).to eq("ORD001")
  end

  it "places an order from a struct built with camelCase keys via from_h" do
    stub_request(:post, %r{/v2/orders\z}).to_return(
      status: 200,
      body: { orderId: "ORD002", orderStatus: "PENDING" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    built = DhanHQ::Contract::Params::OrderParams.from_h(
      "transactionType" => "SELL", "exchangeSegment" => "BSE_EQ", "productType" => "CNC",
      "orderType" => "MARKET", "securityId" => "11536", "quantity" => 1, "validity" => "DAY"
    )
    expect(resource.create(built)["orderId"]).to eq("ORD002")
  end

  it "sends algo_id from a struct under the algoId wire key" do
    stub = stub_request(:post, %r{/v2/orders\z}).with { |req| JSON.parse(req.body)["algoId"] == "1234" }
                                                .to_return(status: 200,
                                                           body: { orderId: "ORD003", orderStatus: "PENDING" }.to_json,
                                                           headers: { "Content-Type" => "application/json" })

    expect(resource.create(struct.merge(algo_id: "1234"))["orderId"]).to eq("ORD003")
    expect(stub).to have_been_requested
  end

  it "sends algo_id from a hash payload under the algoId wire key" do
    stub = stub_request(:post, %r{/v2/orders\z}).with { |req| JSON.parse(req.body)["algoId"] == "1234" }
                                                .to_return(status: 200,
                                                           body: { orderId: "ORD004", orderStatus: "PENDING" }.to_json,
                                                           headers: { "Content-Type" => "application/json" })

    resource.create(transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
                    order_type: "LIMIT", security_id: "11536", quantity: 5, price: 195.5,
                    validity: "DAY", algo_id: "1234")
    expect(stub).to have_been_requested
  end

  it "fails at the call site on a schema violation before any socket opens" do
    request_stub = stub_request(:post, %r{/v2/orders\z}).to_return(status: 200, body: "{}")

    expect { resource.create(DhanHQ::Contract::Params::OrderParams.new(transaction_type: "BUY")) }
      .to raise_error(DhanHQ::ValidationError, /missing required field/)

    expect(request_stub).not_to have_been_requested
  end
end
