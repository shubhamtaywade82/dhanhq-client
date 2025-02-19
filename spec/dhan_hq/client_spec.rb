# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  let(:api_type) { :order_api }
  let(:client) { described_class.new(api_type: api_type) }
  # let(:rate_limiter) { instance_spy(DhanHQ::RateLimiter, throttle!: true) }
  let(:order_id) { "112111182198" }
  let(:order_payload) do
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

  before do
    DhanHQ.configure_with_env
  end

  describe "#initialize" do
    it "creates a Faraday connection" do
      expect(client.connection).to be_a(Faraday::Connection)
    end

    # it "initializes the RateLimiter with correct api_type" do
    #   client
    #   expect(DhanHQ::RateLimiter).to have_received(:new).with(api_type)
    # end

    it "raises an error if RateLimiter fails to initialize" do
      allow(DhanHQ::RateLimiter).to receive(:new).and_return(nil)
      expect { described_class.new(api_type: api_type) }.to raise_error("RateLimiter initialization failed")
    end
  end

  describe "#request" do
    context "when making a GET request", vcr: { cassette_name: "client/get_request" } do
      let(:endpoint) { "/v2/orders/#{order_id}" }

      it "retrieves order details" do
        response = client.request(:get, endpoint, {})
        expect(response).to be_a(Hash)
        expect(response).to include("orderId" => order_id, "orderStatus" => "PENDING")
      end
    end

    context "when making a POST request", vcr: { cassette_name: "client/post_request" } do
      let(:endpoint) { "/v2/orders" }

      it "places a new order" do
        response = client.request(:post, endpoint, order_payload)
        expect(response).to be_a(Hash)
        expect(response).to include("orderId", "orderStatus")
        expect(response["orderStatus"]).to eq("PENDING")
      end
    end

    context "when response is not valid JSON", vcr: { cassette_name: "client/invalid_json_response" } do
      let(:endpoint) { "/v2/orders/#{order_id}" }

      it "returns an empty hash for invalid JSON response" do
        response = client.request(:get, endpoint, {})
        expect(response).to eq([])
      end
    end

    context "when an API error occurs", vcr: { cassette_name: "client/error_dh_905" } do
      let(:endpoint) { "/v2/orders/#{order_id}" }

      it "raises InputExceptionError for invalid request" do
        expect { client.request(:get, endpoint, {}) }
          .to raise_error(DhanHQ::InputExceptionError, /Missing required fields, bad values for parameters/i)
      end
    end
  end

  describe "#build_headers" do
    let(:data_api_path) { "/v2/marketfeed/ltp" }
    let(:non_data_api_path) { "/v2/orders" }

    it "includes client-id for data APIs" do
      expect(client.send(:build_headers, data_api_path)).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "does not include client-id for non-data APIs" do
      expect(client.send(:build_headers, non_data_api_path)).not_to include("client-id")
    end
  end

  describe "#prepare_payload" do
    let(:req) { instance_double(Faraday::Request, body: nil, params: nil) }

    it "raises an error if payload is not a hash" do
      expect { client.send(:prepare_payload, req, "invalid", :post) }
        .to raise_error(DhanHQ::InputExceptionError, /Invalid payload/)
    end

    it "sets params for GET request" do
      expect(req).to receive(:params=).with({ query: "value" })
      client.send(:prepare_payload, req, { query: "value" }, :get)
    end

    it "sets body for POST request" do
      expect(req).to receive(:body=).with(order_payload.to_json)
      client.send(:prepare_payload, req, order_payload, :post)
    end
  end

  describe "#handle_response" do
    let(:response) { instance_double(Faraday::Response, status: response_status, body: response_body) }

    context "when response is successful" do
      let(:response_status) { 200 }
      let(:response_body) { { success: true } }

      it "returns parsed JSON" do
        expect(client.send(:handle_response, response)).to eq(response_body.with_indifferent_access)
      end
    end

    context "when response has an error status" do
      let(:response_status) { 400 }
      let(:endpoint) { "/v2/orders/#{order_id}" }
      let(:error_response) do
        { errorType: "Input_Exception", errorCode: "DH-905",
          errorMessage: "Missing required fields, bad values for parameters etc." }
      end

      it "raises InputExceptionError for invalid request", vcr: { cassette_name: "client/error_response" } do
        expect { client.request(:put, endpoint, {}) }
          .to raise_error(DhanHQ::InputExceptionError, /Missing required fields, bad values for parameters/i)
      end
    end
  end
end
