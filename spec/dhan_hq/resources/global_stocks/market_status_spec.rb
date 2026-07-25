# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::MarketStatus do
  subject(:resource) { described_class.new }

  before { DhanHQ.configure_with_env }

  it "GETs /v2/globalstocks/marketstatus" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/marketstatus")
      .to_return(status: 200, body: { status: "open", marketOpenTime: "09:30" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(resource.fetch["status"]).to eq("open")
  end
end
