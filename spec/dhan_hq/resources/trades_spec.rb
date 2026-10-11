# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Trades do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/trades" }
  let(:trade) do
    {
      dhanClientId: "1100003626",
      orderId: "112025000000001",
      exchangeOrderId: "130000000567890",
      securityId: "1333",
      tradedQuantity: 10,
      tradedPrice: 2455.75,
      orderStatus: "TRADED"
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#all" do
    it "GETs /v2/trades" do
      stub_request(:get, base)
        .to_return(status: 200, body: [trade].to_json, headers: { "Content-Type" => "application/json" })

      resource.all

      expect(WebMock).to have_requested(:get, base)
    end

    it "returns the day's trades with indifferent access" do
      stub_request(:get, base)
        .to_return(status: 200, body: [trade].to_json, headers: { "Content-Type" => "application/json" })

      response = resource.all

      expect(response).to be_an(Array)
      expect(response.first["orderId"]).to eq("112025000000001")
      expect(response.first[:tradedPrice]).to eq(2455.75)
    end

    it "returns an empty array when there are no trades" do
      stub_request(:get, base)
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(resource.all).to eq([])
    end
  end

  describe "#find" do
    it "GETs /v2/trades/{order-id}" do
      stub_request(:get, "#{base}/112025000000001")
        .to_return(status: 200, body: [trade].to_json, headers: { "Content-Type" => "application/json" })

      resource.find("112025000000001")

      expect(WebMock).to have_requested(:get, "#{base}/112025000000001")
    end

    it "raises NotFoundError for an unknown order id" do
      stub_request(:get, "#{base}/999").to_return(
        status: 404,
        body: { errorCode: "TT-404", errorMessage: "Order not found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.find("999") }.to raise_error(DhanHQ::NotFoundError)
    end
  end
end
