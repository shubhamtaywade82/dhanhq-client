# frozen_string_literal: true

require "spec_helper"

RSpec.describe "contract-first request validation in the client" do
  let(:headers) do
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "access-token" => "test-token",
      "client-id" => "1000000001"
    }
  end

  before do
    stub_const("ENV", ENV.to_h.merge("DHAN_ACCESS_TOKEN" => "test-token", "DHAN_CLIENT_ID" => "1000000001"))
    DhanHQ.configure_with_env
  end

  after { DhanHQ.reset_configuration! }

  it "rejects a payload the contract invalidates BEFORE any HTTP request is made" do
    client = DhanHQ::Client.new

    expect do
      client.post("/v2/orders", { securityId: "1333" })
    end.to raise_error(DhanHQ::ValidationError, /placeorder/)

    # Nothing hit the wire — WebMock would raise on an unstubbed request.
  end

  it "sends schema-valid payloads through unchanged" do
    stub_request(:post, "https://api.dhan.co/v2/orders").to_return(
      status: 200, body: { orderId: "OID-1", orderStatus: "PENDING" }.to_json
    )
    client = DhanHQ::Client.new

    expect(client.post("/v2/orders", transactionType: "BUY", exchangeSegment: "NSE_EQ",
                                   securityId: "1333", quantity: 1, productType: "CNC",
                                   orderType: "LIMIT", validity: "DAY")).to include(:orderId)
  end

  it "can be disabled per configuration" do
    DhanHQ.configuration.validate_requests = false
    stub_request(:post, "https://api.dhan.co/v2/orders").to_return(
      status: 200, body: { orderId: "OID-2", orderStatus: "PENDING" }.to_json
    )
    client = DhanHQ::Client.new

    # The payload violates the contract but skips schema validation.
    expect(client.post("/v2/orders", { securityId: "1333" })).to include(:orderId)
  end

  it "does not validate endpoints absent from the contract (iceberg, twap)" do
    client = DhanHQ::Client.new

    expect(DhanHQ::Contract::Registry.resolve(:post, "/v2/orders/iceberg")).to be_nil
    expect(DhanHQ::Contract::Registry.resolve(:post, "/v2/orders/twap")).to be_nil
  end
end
