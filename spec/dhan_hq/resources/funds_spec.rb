# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::Funds do
  subject(:resource) { described_class.new }

  let(:funds_response) do
    {
      "dhanClientId" => "test_client",
      "availabelBalance" => 50_000.0,
      "sodLimit" => 100_000.0,
      "collateralAmount" => 10_000.0,
      "receiveableAmount" => 0.0,
      "utilizedAmount" => 50_000.0,
      "blockedPayoutAmount" => 0.0,
      "withdrawableBalance" => 50_000.0
    }
  end

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end

    stub_request(:get, "https://api.dhan.co/v2/fundlimit")
      .to_return(status: 200, body: funds_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch" do
    it "returns a hash with fund data" do
      result = resource.fetch
      expect(result).to be_a(Hash)
    end

    it "includes available balance information" do
      result = resource.fetch
      expect(result).to have_key("availabelBalance")
    end
  end
end
