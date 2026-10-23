# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::RequestHelper do
  let(:helper_class) do
    Class.new do
      include DhanHQ::RequestHelper

      public :build_headers, :data_api?, :prepare_payload
    end
  end
  let(:helper) { helper_class.new }

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#data_api?" do
    it "returns true for option chain paths" do
      expect(helper.data_api?("/v2/optionchain")).to be true
    end

    it "returns true for market feed paths" do
      expect(helper.data_api?("/v2/marketfeed/ltp")).to be true
    end

    it "returns true for instrument download paths" do
      expect(helper.data_api?("/v2/instrument/NSE")).to be true
    end

    it "returns false for order paths" do
      expect(helper.data_api?("/v2/orders")).to be false
    end

    it "returns true for historical data paths (/v2/charts is a data API prefix)" do
      expect(helper.data_api?("/v2/charts/historical")).to be true
    end
  end

  describe "#build_headers" do
    context "when the path is the instrument CSV endpoint" do
      it "returns only the Accept: text/csv header (no auth)" do
        result = helper.build_headers("/v2/instrument/NSE_EQ")
        expect(result).to eq({ "Accept" => "text/csv" })
      end
    end

    context "when the path is a standard trading endpoint" do
      it "includes Content-Type, Accept, and access-token headers" do
        result = helper.build_headers("/v2/orders")
        expect(result["Content-Type"]).to eq("application/json")
        expect(result["Accept"]).to eq("application/json")
        expect(result["access-token"]).to eq("test_token")
      end

      it "does not include client-id for non-data-api paths" do
        result = helper.build_headers("/v2/orders")
        expect(result).not_to have_key("client-id")
      end
    end

    context "when the path is a data API endpoint (option chain)" do
      it "includes the client-id header" do
        result = helper.build_headers("/v2/optionchain")
        expect(result["client-id"]).to eq("test_client")
      end
    end

    context "when the access token is missing" do
      before do
        DhanHQ.configure do |c|
          c.access_token = nil
          c.client_id = "test_client"
        end
      end

      it "raises AuthenticationError" do
        expect { helper.build_headers("/v2/orders") }
          .to raise_error(DhanHQ::AuthenticationError, /Missing access token/)
      end
    end

    context "when client_id is missing for a data API" do
      before do
        DhanHQ.configure do |c|
          c.access_token = "test_token"
          c.client_id = nil
        end
      end

      it "raises InvalidAuthenticationError" do
        expect { helper.build_headers("/v2/optionchain") }
          .to raise_error(DhanHQ::InvalidAuthenticationError, /client_id is required/)
      end
    end
  end

  describe "#prepare_payload" do
    let(:req) { instance_double(Faraday::Request).as_null_object }

    context "when payload is nil" do
      it "does nothing (no-op)" do
        expect { helper.prepare_payload(req, nil, :post) }.not_to raise_error
      end
    end

    context "when payload is empty" do
      it "does nothing (no-op)" do
        allow(req).to receive(:body=)
        helper.prepare_payload(req, {}, :post)
        expect(req).not_to have_received(:body=)
      end
    end

    context "when the request method is GET" do
      it "assigns payload to req.params" do
        allow(req).to receive(:params=)
        helper.prepare_payload(req, { foo: "bar" }, :get)
        expect(req).to have_received(:params=).with({ foo: "bar" })
      end
    end

    context "when the request method is POST" do
      it "serialises payload as JSON and assigns to req.body" do
        allow(req).to receive(:body=)
        helper.prepare_payload(req, { foo: "bar" }, :post)
        expect(req).to have_received(:body=).with({ foo: "bar" }.to_json)
      end
    end

    context "when the request method is PUT" do
      it "serialises payload as JSON and assigns to req.body" do
        allow(req).to receive(:body=)
        helper.prepare_payload(req, { qty: 5 }, :put)
        expect(req).to have_received(:body=).with({ qty: 5 }.to_json)
      end
    end

    context "when the request method is DELETE" do
      it "clears req.params" do
        allow(req).to receive(:params=)
        helper.prepare_payload(req, { id: 1 }, :delete)
        expect(req).to have_received(:params=).with({})
      end
    end

    context "when payload is not a Hash" do
      it "raises InputExceptionError" do
        expect { helper.prepare_payload(req, "bad_payload", :post) }
          .to raise_error(DhanHQ::InputExceptionError, /Expected a Hash/)
      end
    end
  end
end
