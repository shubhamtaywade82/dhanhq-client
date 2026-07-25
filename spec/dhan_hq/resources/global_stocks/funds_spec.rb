# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::Funds do
  subject(:resource) { described_class.new }

  before { DhanHQ.configure_with_env }

  it "GETs /v2/globalstocks/fundlimit" do
    stub_request(:get, "https://api.dhan.co/v2/globalstocks/fundlimit")
      .to_return(status: 200, body: { availableCash: 1500.25 }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(resource.fetch["availableCash"]).to eq(1500.25)
  end
end
