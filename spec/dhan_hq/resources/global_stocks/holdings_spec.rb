# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::Holdings do
  subject(:resource) { described_class.new }

  before { DhanHQ.configure_with_env }

  it "GETs /v2/globalstocks/holdings" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/holdings")
      .to_return(status: 200, body: [{ tradingSymbol: "AAPL", quantity: 2.5 }].to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(resource.all.first["tradingSymbol"]).to eq("AAPL")
  end

  it "sends the access token header" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/holdings")
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

    resource.all

    expect(WebMock).to have_requested(:get, "https://api.dhan.co/v2/globalstocks/holdings")
      .with(headers: { "access-token" => DhanHQ.configuration.access_token })
  end
end
