# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::IPSetup do
  subject(:ip_setup) { described_class.new }

  let(:client) { instance_double(DhanHQ::Client) }

  before do
    allow(DhanHQ::Client).to receive(:new).and_return(client)
    allow(DhanHQ.configuration).to receive(:client_id).and_return("1234567890")
  end

  describe "#current" do
    it "calls GET /v2/ip/getIP" do
      allow(client).to receive(:get).with("/v2/ip/getIP", {}).and_return({ status: "success", data: {} })
      ip_setup.current
      expect(client).to have_received(:get).with("/v2/ip/getIP", {})
    end
  end

  describe "#set" do
    it "calls POST /v2/ip/setIP with SECONDARY flag" do
      expected_params = {
        "ip" => "1.2.3.4",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "1234567890"
      }
      allow(client).to receive(:post).with("/v2/ip/setIP", expected_params).and_return({ status: "success" })

      ip_setup.set(ip: "1.2.3.4", ip_flag: "SECONDARY")
      expect(client).to have_received(:post).with("/v2/ip/setIP", expected_params)
    end

    it "uses provided dhan_client_id" do
      expected_params = {
        "ip" => "1.2.3.4",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "9999999999"
      }
      allow(client).to receive(:post).with("/v2/ip/setIP", expected_params).and_return({ status: "success" })

      ip_setup.set(ip: "1.2.3.4", ip_flag: "SECONDARY", dhan_client_id: "9999999999")
      expect(client).to have_received(:post).with("/v2/ip/setIP", expected_params)
    end
  end

  describe "#update" do
    it "calls PUT /v2/ip/modifyIP with SECONDARY flag" do
      expected_params = {
        "ip" => "5.6.7.8",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "1234567890"
      }
      allow(client).to receive(:put).with("/v2/ip/modifyIP", expected_params).and_return({ status: "success" })

      ip_setup.update(ip: "5.6.7.8", ip_flag: "SECONDARY")
      expect(client).to have_received(:put).with("/v2/ip/modifyIP", expected_params)
    end
  end

  describe "request wire format" do
    subject(:ip_setup) { described_class.new }

    let(:base) { "https://api.dhan.co/v2/ip" }

    before do
      allow(DhanHQ::Client).to receive(:new).and_call_original
      ENV["DHAN_CLIENT_ID"] = "test_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "GETs /v2/ip/getIP and returns the whitelisted IPs" do
      stub_request(:get, "#{base}/getIP").to_return(
        status: 200,
        body: { primaryIP: "1.2.3.4", secondaryIP: "5.6.7.8" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      response = ip_setup.current

      expect(WebMock).to have_requested(:get, "#{base}/getIP")
      expect(response["primaryIP"]).to eq("1.2.3.4")
    end

    it "POSTs camelized params to /v2/ip/setIP with the configured client id" do
      stub_request(:post, "#{base}/setIP")
        .to_return(status: 200, body: { status: "success" }.to_json, headers: { "Content-Type" => "application/json" })

      ip_setup.set(ip: "1.2.3.4", ip_flag: "SECONDARY")

      expect(WebMock).to(have_requested(:post, "#{base}/setIP").with do |req|
        JSON.parse(req.body).values_at("ip", "ipFlag", "dhanClientId") == ["1.2.3.4", "SECONDARY", "test_client_id"]
      end)
    end

    it "PUTs camelized params to /v2/ip/modifyIP" do
      stub_request(:put, "#{base}/modifyIP")
        .to_return(status: 200, body: { status: "success" }.to_json, headers: { "Content-Type" => "application/json" })

      ip_setup.update(ip: "9.9.9.9", ip_flag: "PRIMARY", dhan_client_id: "9999999999")

      expect(WebMock).to(have_requested(:put, "#{base}/modifyIP").with do |req|
        JSON.parse(req.body).values_at("ip", "ipFlag", "dhanClientId") == ["9.9.9.9", "PRIMARY", "9999999999"]
      end)
    end

    it "raises InputExceptionError when the IP is rejected" do
      stub_request(:post, "#{base}/setIP").to_return(
        status: 400,
        body: { errorCode: "DH-905", errorMessage: "Invalid IP" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { ip_setup.set(ip: "not-an-ip") }.to raise_error(DhanHQ::InputExceptionError)
    end
  end
end
