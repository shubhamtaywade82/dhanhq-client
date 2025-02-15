# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  let(:api_type) { :order_api }
  let(:client) { described_class.new(api_type: api_type) }
  let(:rate_limiter) { instance_spy(DhanHQ::RateLimiter, throttle!: true) }

  before do
    # VCR.turn_off!
    # Prevent real rate limiting but ensure `throttle!` is being called
    allow(DhanHQ::RateLimiter).to receive(:new).with(api_type).and_return(rate_limiter)

    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token  = "test_access_token"
      config.client_id     = "test_client_id"
    end
  end

  # after { VCR.turn_on! }

  describe "#initialize" do
    it "creates a Faraday connection" do
      expect(client.connection).to be_a(Faraday::Connection)
    end

    it "initializes the RateLimiter with correct api_type" do
      client
      expect(DhanHQ::RateLimiter).to have_received(:new).with(api_type)
    end

    it "raises an error if RateLimiter fails to initialize" do
      allow(DhanHQ::RateLimiter).to receive(:new).and_return(nil)
      expect { described_class.new(api_type: api_type) }.to raise_error("RateLimiter initialization failed")
    end
  end

  describe "#request" do
    let(:path) { "/v2/orders" }
    let(:payload) { { orderId: "12345" } }
    let(:headers) do
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "access-token" => "test_access_token"
      }
    end

    before do
      stub_request(:post, "https://api.dhan.co#{path}")
        .with(body: payload.to_json, headers: headers)
        .to_return(status: response_status, body: response_body.to_json)
    end

    context "when request is successful" do
      let(:response_status) { 200 }
      let(:response_body) { { orderStatus: "PENDING", orderId: "12345" } }

      it "calls the rate limiter before sending request" do
        client.request(:post, path, payload)
        expect(rate_limiter).to have_received(:throttle!).once
      end

      it "returns a HashWithIndifferentAccess" do
        response = client.request(:post, path, payload)
        expect(response).to be_a(Hash)
        expect(response[:orderId]).to eq("12345")
      end

      it "sends the correct HTTP method and path" do
        client.request(:post, path, payload)
        expect(WebMock).to have_requested(:post, "https://api.dhan.co#{path}")
      end
    end

    context "when response is not valid JSON" do
      let(:response_status) { 200 }
      let(:response_body) { "<html>Invalid Response</html>" }

      it "returns an empty hash" do
        response = client.request(:post, path, payload)
        expect(response).to eq({})
      end
    end

    context "when an error occurs" do
      shared_examples "an API error" do |status_code, error_class, message_fragment|
        let(:response_status) { status_code }
        let(:response_body) { { error: message_fragment } }

        it "raises #{error_class}" do
          expect { client.request(:post, path, payload) }
            .to raise_error(error_class, /#{message_fragment}/i)
        end
      end

      it_behaves_like "an API error", 400, DhanHQ::InputExceptionError, "Bad Request"
      it_behaves_like "an API error", 401, DhanHQ::InvalidAuthenticationError, "Unauthorized"
      it_behaves_like "an API error", 403, DhanHQ::InvalidAccessError, "Forbidden"
      it_behaves_like "an API error", 404, DhanHQ::NotFoundError, "Not Found"
      it_behaves_like "an API error", 429, DhanHQ::RateLimitError, "Rate Limit"
      it_behaves_like "an API error", 500, DhanHQ::InternalServerError, "Server Error"
      it_behaves_like "an API error", 503, DhanHQ::InternalServerError, "Server Error"

      context "when the status code is unknown" do
        let(:response_status) { 999 }
        let(:response_body) { { error: "Unknown Error" } }

        it "raises DhanHQ::OtherError" do
          expect { client.request(:post, path, payload) }
            .to raise_error(DhanHQ::OtherError, /Unknown Error/)
        end
      end
    end
  end

  describe "#build_headers" do
    context "for a data API request" do
      let(:data_api_path) { "/v2/marketfeed/ltp" }

      it "includes client-id header" do
        expect(client.send(:build_headers, data_api_path)).to include("client-id" => "test_client_id")
      end
    end

    context "for a non-data API request" do
      let(:non_data_api_path) { "/v2/orders" }

      it "does not include client-id header" do
        expect(client.send(:build_headers, non_data_api_path)).not_to include("client-id")
      end
    end
  end

  describe "#prepare_payload" do
    let(:req) { instance_double(Faraday::Request, body: nil, params: nil) }

    it "raises an error if payload is not a hash" do
      expect { client.send(:prepare_payload, req, "not a hash", :post) }
        .to raise_error(DhanHQ::InputExceptionError, /Invalid payload/)
    end

    it "sets params for GET request" do
      expect(req).to receive(:params=).with({ query: "value" })
      client.send(:prepare_payload, req, { query: "value" }, :get)
    end

    it "sets body for POST request" do
      expect(req).to receive(:body=).with({ data: "value" }.to_json)
      client.send(:prepare_payload, req, { data: "value" }, :post)
    end
  end

  describe "#handle_response" do
    let(:response) { instance_double(Faraday::Response, status: response_status, body: response_body.to_json) }

    context "when response is successful" do
      let(:response_status) { 200 }
      let(:response_body) { { success: true } }

      it "returns parsed JSON" do
        expect(client.send(:handle_response, response)).to eq(response_body.with_indifferent_access)
      end
    end

    context "when response has an error status" do
      let(:response_status) { 400 }
      let(:response_body) { { error: "Bad Request" } }

      it "raises the correct error" do
        expect { client.send(:handle_response, response) }
          .to raise_error(DhanHQ::InputExceptionError, /Bad Request/)
      end
    end
  end
end
