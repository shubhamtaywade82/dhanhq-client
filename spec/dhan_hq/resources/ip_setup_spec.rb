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
      expect(client).to receive(:get).with("/v2/ip/getIP", {}).and_return({ status: "success", data: {} })
      ip_setup.current
    end
  end

  describe "#set" do
    it "calls POST /v2/ip/setIP with SECONDARY flag" do
      expected_params = {
        "ip" => "1.2.3.4",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "1234567890"
      }
      expect(client).to receive(:post).with("/v2/ip/setIP", expected_params).and_return({ status: "success" })
      
      ip_setup.set(ip: "1.2.3.4", ip_flag: "SECONDARY")
    end

    it "uses provided dhan_client_id" do
      expected_params = {
        "ip" => "1.2.3.4",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "9999999999"
      }
      expect(client).to receive(:post).with("/v2/ip/setIP", expected_params).and_return({ status: "success" })
      
      ip_setup.set(ip: "1.2.3.4", ip_flag: "SECONDARY", dhan_client_id: "9999999999")
    end
  end

  describe "#update" do
    it "calls PUT /v2/ip/modifyIP with SECONDARY flag" do
      expected_params = {
        "ip" => "5.6.7.8",
        "ipFlag" => "SECONDARY",
        "dhanClientId" => "1234567890"
      }
      expect(client).to receive(:put).with("/v2/ip/modifyIP", expected_params).and_return({ status: "success" })
      
      ip_setup.update(ip: "5.6.7.8", ip_flag: "SECONDARY")
    end
  end
end
