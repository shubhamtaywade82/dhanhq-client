# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::OptionChain do
  subject(:resource) { described_class.new }

  let(:option_chain_response) do
    {
      "data" => {
        "oc" => {
          "25000" => {
            "call" => { "last_price" => 100.0 },
            "put"  => { "last_price" => 50.0 }
          }
        }
      }
    }
  end

  let(:fetch_params) do
    { underlying_scrip: 13, underlying_seg: "IDX_I", expiry: "2025-01-30" }
  end

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#fetch" do
    before do
      stub_request(:post, "https://api.dhan.co/v2/optionchain")
        .to_return(status: 200, body: option_chain_response.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash" do
      result = resource.fetch(fetch_params)
      expect(result).to be_a(Hash)
    end
  end

  describe "#expirylist" do
    let(:expiry_response) { { "data" => ["2025-01-30", "2025-02-27"] } }

    before do
      stub_request(:post, "https://api.dhan.co/v2/optionchain/expirylist")
        .to_return(status: 200, body: expiry_response.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash with expiry dates" do
      result = resource.expirylist(fetch_params)
      expect(result).to be_a(Hash)
    end
  end
end
