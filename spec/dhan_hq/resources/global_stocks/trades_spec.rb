# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::Trades do
  subject(:resource) { described_class.new }

  before { DhanHQ.configure_with_env }

  it "GETs the trade book" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/trades")
      .to_return(status: 200, body: [{ orderId: "1", tradedPrice: 180.5 }].to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(resource.all.first["tradedPrice"]).to eq(180.5)
  end

  it "GETs trades scoped to a security" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/trades/AAPL")
      .to_return(status: 200, body: [{ orderId: "1", securityId: "AAPL" }].to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(resource.by_security_id("AAPL").first["securityId"]).to eq("AAPL")
  end
end
