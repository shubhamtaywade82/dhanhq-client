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
    before do
      ENV["CLIENT_ID"] = "test_client_id"
      ENV["ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "creates a Faraday connection" do
      expect(client.connection).to be_a(Faraday::Connection)
    end

    it "sets timeout configuration" do
      expect(client.connection.options.timeout).to eq(30)
      expect(client.connection.options.open_timeout).to eq(10)
      expect(client.connection.options.write_timeout).to eq(30)
    end

    it "raises an error if RateLimiter fails to initialize" do
      allow(DhanHQ::RateLimiter).to receive(:for).and_return(nil)
      expect do
        described_class.new(api_type: api_type)
      end.to raise_error(DhanHQ::Error, /RateLimiter initialization failed/)
    end

    context "when CLIENT_ID is set but ACCESS_TOKEN is missing" do
      before do
        ENV["CLIENT_ID"] = "test_client_id"
        ENV.delete("ACCESS_TOKEN")
        DhanHQ.configure_with_env
      end

      it "does not raise error during initialization (validation happens at request time)" do
        expect { described_class.new(api_type: api_type) }.not_to raise_error
      end

      it "raises error when making a request without access_token" do
        client = described_class.new(api_type: api_type)
        expect { client.get("/v2/orders") }
          .to raise_error(DhanHQ::AuthenticationError, /Missing access token/)
      end
    end

    context "when ACCESS_TOKEN is set but CLIENT_ID is missing" do
      before do
        ENV.delete("CLIENT_ID")
        ENV["ACCESS_TOKEN"] = "test_access_token"
        DhanHQ.configure_with_env
      end

      it "does not raise error (CLIENT_ID not required for all APIs)" do
        expect { described_class.new(api_type: api_type) }.not_to raise_error
      end
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

    context "when response is not valid JSON" do
      let(:endpoint) { "/v2/orders/#{order_id}" }
      let(:invalid_json_response) { instance_double(Faraday::Response, status: 200, body: "invalid json") }

      before do
        allow(client.connection).to receive(:get).and_return(invalid_json_response)
      end

      it "raises DataError for invalid JSON response" do
        expect { client.request(:get, endpoint, {}) }
          .to raise_error(DhanHQ::DataError, /Failed to parse JSON response/)
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

    before do
      ENV["CLIENT_ID"] = "test_client_id"
      ENV["ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "includes client-id for data APIs" do
      expect(client.send(:build_headers, data_api_path)).to include("client-id" => DhanHQ.configuration.client_id)
    end

    it "does not include client-id for non-data APIs" do
      expect(client.send(:build_headers, non_data_api_path)).not_to include("client-id")
    end

    context "when access_token is missing" do
      before do
        # Clear ENV to prevent Client#initialize from auto-reloading access_token
        ENV.delete("ACCESS_TOKEN")
        DhanHQ.configuration.access_token = nil
      end

      it "raises AuthenticationError" do
        expect { client.send(:build_headers, non_data_api_path) }
          .to raise_error(DhanHQ::AuthenticationError, /Missing access token/)
      end
    end

    context "when client_id is missing for data API" do
      before do
        # Clear ENV to prevent Client#initialize from auto-reloading client_id
        ENV.delete("CLIENT_ID")
        DhanHQ.configuration.client_id = nil
      end

      it "raises InvalidAuthenticationError" do
        expect { client.send(:build_headers, data_api_path) }
          .to raise_error(DhanHQ::InvalidAuthenticationError, /client_id is required for DATA APIs/)
      end
    end
  end

  describe "#prepare_payload" do
    let(:req) { instance_double(Faraday::Request, body: nil, params: nil) }

    it "raises an error if payload is not a hash" do
      expect { client.send(:prepare_payload, req, "invalid", :post) }
        .to raise_error(DhanHQ::InputExceptionError, /Invalid payload/)
    end

    it "sets params for GET request" do
      allow(req).to receive(:params=)
      client.send(:prepare_payload, req, { query: "value" }, :get)
      expect(req).to have_received(:params=).with({ query: "value" })
    end

    it "sets body for POST request" do
      allow(req).to receive(:body=)
      client.send(:prepare_payload, req, order_payload, :post)
      expect(req).to have_received(:body=).with(order_payload.to_json)
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

  describe "auth failures (WebMock)" do
    # VCR shows final URI as https://api.dhan.co/v2/orders when path is /v2/orders
    let(:orders_url) { "https://api.dhan.co/v2/orders" }

    context "when API returns 401" do
      before do
        DhanHQ.configure do |c|
          c.client_id = "test_client_id"
          c.access_token = "test_access_token"
          c.access_token_provider = nil
        end
        stub_request(:get, orders_url)
          .to_return(
            status: 401,
            body: { errorType: "Invalid_Authentication", errorCode: "DH-901",
                    errorMessage: "Client ID or user generated access token is invalid or expired." }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises InvalidAuthenticationError" do
        expect { client.get("/v2/orders") }
          .to raise_error(DhanHQ::InvalidAuthenticationError, /DH-901|invalid or expired/)
      end
    end

    context "when API returns 403" do
      before do
        DhanHQ.configure do |c|
          c.client_id = "test_client_id"
          c.access_token = "test_access_token"
          c.access_token_provider = nil
        end
        stub_request(:get, orders_url)
          .to_return(
            status: 403,
            body: { errorCode: "DH-902", errorMessage: "Access denied" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises InvalidAccessError" do
        expect { client.get("/v2/orders") }
          .to raise_error(DhanHQ::InvalidAccessError, /DH-902|Access denied/)
      end
    end

    context "when API returns 401 then 200 and access_token_provider is set" do
      let(:token_call_count) { [0] }
      let(:token_provider) do
        count = token_call_count
        lambda do
          count[0] += 1
          count[0] == 1 ? "expired_token" : "fresh_token"
        end
      end

      before do
        DhanHQ.configure do |config|
          config.client_id = "test_client_id"
          config.access_token = nil
          config.access_token_provider = token_provider
        end

        stub_request(:get, orders_url)
          .with(headers: { "Access-Token" => "expired_token" })
          .to_return(
            status: 401,
            body: { errorCode: "DH-901", errorMessage: "Token invalid or expired" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        stub_request(:get, orders_url)
          .with(headers: { "Access-Token" => "fresh_token" })
          .to_return(
            status: 200,
            body: { orderId: "123", orderStatus: "PENDING" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retries once with fresh token and returns success" do
        response = client.get("/v2/orders")
        expect(response["orderId"]).to eq("123")
        expect(response["orderStatus"]).to eq("PENDING")
      end

      it "calls access_token_provider twice (initial + retry)" do
        client.get("/v2/orders")
        expect(token_call_count[0]).to eq(2)
      end
    end

    context "when API returns 401 twice and access_token_provider is set" do
      before do
        DhanHQ.configure do |config|
          config.client_id = "test_client_id"
          config.access_token = nil
          config.access_token_provider = -> { "same_token" }
        end

        stub_request(:get, orders_url)
          .with(headers: { "Access-Token" => "same_token" })
          .to_return(
            status: 401,
            body: { errorCode: "DH-901", errorMessage: "Token invalid" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retries once then raises InvalidAuthenticationError" do
        expect { client.get("/v2/orders") }
          .to raise_error(DhanHQ::InvalidAuthenticationError)
      end
    end

    context "when API returns 401 with errorCode 807 (token expired)" do
      before do
        DhanHQ.configure do |c|
          c.client_id = "test_client_id"
          c.access_token = "test_access_token"
          c.access_token_provider = nil
        end
        stub_request(:get, orders_url)
          .to_return(
            status: 401,
            body: { errorCode: "807", errorMessage: "Token expired" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises TokenExpiredError" do
        expect { client.get("/v2/orders") }
          .to raise_error(DhanHQ::TokenExpiredError, /807|Token expired/)
      end
    end

    context "when on_token_expired hook is set and 401 triggers retry" do
      let(:hook_state) { { called: false, error: nil } }

      before do
        DhanHQ.configure do |config|
          config.client_id = "test_client_id"
          config.access_token = nil
          config.access_token_provider = -> { "fresh_token" }
          config.on_token_expired = lambda do |err|
            hook_state[:called] = true
            hook_state[:error] = err
          end
        end

        stub_request(:get, orders_url)
          .with(headers: { "Access-Token" => "fresh_token" })
          .to_return(
            status: 401,
            body: { errorCode: "DH-901", errorMessage: "Expired" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .then.to_return(
            status: 200,
            body: { orderId: "456", orderStatus: "PENDING" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "invokes on_token_expired with the auth error before retry" do
        response = client.get("/v2/orders")
        expect(hook_state[:called]).to be true
        expect(hook_state[:error]).to be_a(DhanHQ::InvalidAuthenticationError)
        expect(response["orderId"]).to eq("456")
      end
    end
  end
end
