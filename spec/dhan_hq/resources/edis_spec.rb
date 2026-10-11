# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Edis do
  subject(:edis) { described_class.new }

  let(:client) { instance_double(DhanHQ::Client) }

  before do
    allow(DhanHQ::Client).to receive(:new).and_return(client)
    allow(client).to receive_messages(post: {}, get: {})
  end

  describe "#form" do
    it "posts to /v2/edis/form with params" do
      edis.form(isin: "INE733E01010", qty: 1, exchange: "NSE", segment: "EQ", bulk: false)

      expect(client).to have_received(:post).with("/v2/edis/form", anything)
    end
  end

  describe "#bulk_form" do
    it "posts to /v2/edis/bulkform with params" do
      edis.bulk_form(exchange: "NSE", segment: "EQ", bulk: true)

      expect(client).to have_received(:post).with("/v2/edis/bulkform", anything)
    end
  end

  describe "#tpin" do
    it "gets /v2/edis/tpin" do
      edis.tpin

      expect(client).to have_received(:get).with("/v2/edis/tpin", {})
    end
  end

  describe "#inquire" do
    it "gets /v2/edis/inquire/{isin}" do
      edis.inquire("INE002A01018")

      expect(client).to have_received(:get).with("/v2/edis/inquire/INE002A01018", {})
    end
  end

  describe "request wire format" do
    subject(:edis) { described_class.new }

    let(:base) { "https://api.dhan.co/v2/edis" }

    before do
      allow(DhanHQ::Client).to receive(:new).and_call_original
      ENV["DHAN_CLIENT_ID"] = "test_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "POSTs the form body to /v2/edis/form" do
      stub_request(:post, "#{base}/form")
        .to_return(status: 200, body: { dhanClientId: "1100003626", edisFormHtml: "<html/>" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      edis.form(isin: "INE733E01010", qty: 1, exchange: "NSE", segment: "EQ", bulk: false)

      expect(WebMock).to(have_requested(:post, "#{base}/form").with do |req|
        JSON.parse(req.body).values_at("isin", "qty", "exchange", "segment", "bulk") ==
          ["INE733E01010", 1, "NSE", "EQ", false]
      end)
    end

    it "POSTs the bulk form body to /v2/edis/bulkform" do
      stub_request(:post, "#{base}/bulkform")
        .to_return(status: 200, body: { dhanClientId: "1100003626", edisFormHtml: "<html/>" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Documented body: isin (array), exchange and segment are required.
      edis.bulk_form(isin: %w[INE733E01010 INE002A01018], exchange: "NSE", segment: "EQ", bulk: true)

      expect(WebMock).to(have_requested(:post, "#{base}/bulkform").with do |req|
        JSON.parse(req.body).values_at("isin", "exchange", "segment") ==
          [%w[INE733E01010 INE002A01018], "NSE", "EQ"]
      end)
    end

    it "returns an accepted status hash when tpin generation answers 202" do
      stub_request(:get, "#{base}/tpin").to_return(status: 202)

      expect(edis.tpin).to eq({ "status" => "accepted" })
    end

    it "GETs /v2/edis/inquire/{isin} and returns the inquiry" do
      stub_request(:get, "#{base}/inquire/INE002A01018").to_return(
        status: 200,
        body: { clientId: "1100003626", isin: "INE002A01018", totalQty: 10, aprvdQty: 10, status: "SUCCESS", remarks: "" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      response = edis.inquire("INE002A01018")

      expect(response["status"]).to eq("SUCCESS")
      expect(response[:totalQty]).to eq(10)
    end
  end
end
