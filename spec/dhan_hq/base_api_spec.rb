# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::BaseAPI do
  let(:api_type) { :order_api }
  let(:client) { DhanHQ::Client.new(api_type: api_type) }
  let(:base_api) { described_class.new(api_type: api_type) }
  let(:endpoint) { "/test_endpoint" }
  let(:params) { { key: "value" } }
  let(:formatted_params) { { "key" => "value" } }

  before do
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "test_access_token"
      config.client_id = "client123"
    end
  end

  describe "#initialize" do
    it "initializes with the correct API type" do
      expect(base_api.client).to be_a(DhanHQ::Client)
    end
  end

  describe "#request" do
    before do
      DhanHQ.configure_with_env
    end

    context "when making a GET request", vcr: { cassette_name: "base_api/get_request" } do
      let(:order_id) { "112111182198" }
      let(:endpoint) { "/v2/orders/#{order_id}" }
      let(:params) { {} } # No params needed for order lookup

      it "sends a GET request with query parameters" do
        response = base_api.request(:get, endpoint, params: params)

        expect(response).to be_a(Hash)
        expect(response).to include(
          "orderId" => "112111182198",
          "orderStatus" => "PENDING",
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ"
        )
      end
    end

    context "when making a POST request", vcr: { cassette_name: "base_api/post_request" } do
      let(:endpoint) { "/v2/orders" }
      let(:params) do
        {
          dhanClientId: "1000000003",
          transactionType: "BUY",
          exchangeSegment: "NSE_EQ",
          productType: "INTRADAY",
          orderType: "MARKET",
          validity: "DAY",
          securityId: "11536",
          quantity: 5
        }
      end

      it "sends a POST request with body parameters" do
        response = base_api.request(:post, endpoint, params: params)
        expect(response).to be_a(Hash)
        expect(response).to have_key("orderId")
      end
    end

    context "when making a DELETE request with path parameter", vcr: { cassette_name: "base_api/delete_request" } do
      let(:order_id) { "112111182198" }
      let(:endpoint) { "/v2/orders/#{order_id}" }

      it "sends a DELETE request to delete an order" do
        response = base_api.request(:delete, endpoint)
        expect(response).to be_a(Hash)
        expect(response["orderStatus"]).to eq("CANCELLED")
      end
    end

    context "when the API returns an error", vcr: { cassette_name: "client/error_dh_905" } do
      let(:endpoint) { "/v2/orders" }
      let(:params) { { invalid_param: true } }

      it "raises an error when the API response contains an error" do
        expect { base_api.request(:post, endpoint, params: params) }
          .to raise_error(DhanHQ::InputExceptionError, /Invalid Input/)
      end
    end

    # it "makes an actual API request and returns a parsed response" do
    #   response = base_api.request(:get, endpoint, params: params)
    #   expect(response).to eq({ "status" => "success" })
    # end

    # # it "raises an error when the API returns an error" do
    # #   stub_request(:get, "https://api.dhan.co#{endpoint}?key=value")
    # #     .to_return(status: 400, body: { "errorCode" => "DH-905", "message" => "Invalid Input" }.to_json)

    # #   expect { base_api.request(:get, endpoint, params: params) }
    # #     .to raise_error(DhanHQ::InputExceptionError, /Invalid Input/)
    # # end
    # it "raises an error when the API returns an error", vcr: { cassette_name: "client/error_dh_905" } do
    #   expect { base_api.request(:get, endpoint, params: params) }
    #     .to raise_error(DhanHQ::InputExceptionError, /Invalid Input/)
    # end
  end

  describe "#get" do
    before do
      stub_request(:get, "https://api.dhan.co#{endpoint}?key=value")
        .to_return(status: 200, body: { "data" => "test" }.to_json)
    end

    it "performs a GET request and returns parsed response" do
      response = base_api.get(endpoint, params: params)
      expect(response).to eq({ "data" => "test" })
    end
  end

  describe "#post" do
    before do
      stub_request(:post, "https://api.dhan.co#{endpoint}")
        .with(body: params.to_json)
        .to_return(status: 201, body: { "created" => true }.to_json)
    end

    it "performs a POST request and returns parsed response" do
      response = base_api.post(endpoint, params: params)
      expect(response).to eq({ "created" => true })
    end
  end

  describe "#put" do
    before do
      stub_request(:put, "https://api.dhan.co#{endpoint}")
        .with(body: params.to_json)
        .to_return(status: 200, body: { "updated" => true }.to_json)
    end

    it "performs a PUT request and returns parsed response" do
      response = base_api.put(endpoint, params: params)
      expect(response).to eq({ "updated" => true })
    end
  end

  describe "#delete" do
    before do
      stub_request(:delete, "https://api.dhan.co#{endpoint}")
        .to_return(status: 200, body: { "deleted" => true }.to_json)
    end

    it "performs a DELETE request and returns parsed response" do
      response = base_api.delete(endpoint)
      expect(response).to eq({ "deleted" => true })
    end
  end

  describe "#handle_response" do
    it "returns response when it's a valid Hash" do
      response = base_api.send(:handle_response, { success: true })
      expect(response).to eq({ success: true })
    end

    it "returns response when it's a valid Array" do
      response = base_api.send(:handle_response, [{ success: true }])
      expect(response).to eq([{ success: true }])
    end

    it "raises an error for invalid response format" do
      expect { base_api.send(:handle_response, "invalid response") }
        .to raise_error(DhanHQ::Error, "Unexpected API response format")
    end
  end

  describe "#handle_error" do
    let(:error_response) { { errorCode: "DH-905", message: "Invalid Input" } }

    it "raises mapped error for known API error codes" do
      expect { base_api.send(:handle_error, error_response) }
        .to raise_error(DhanHQ::InputExceptionError, /Invalid Input/)
    end

    it "raises a generic error for unknown error codes" do
      error_response[:errorCode] = "999"
      expect { base_api.send(:handle_error, error_response) }
        .to raise_error(DhanHQ::Error, "Unknown API error: Invalid Input")
    end
  end
end
