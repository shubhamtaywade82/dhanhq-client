# frozen_string_literal: true

RSpec.describe DhanHQ::Models::OptionChain, vcr: { cassette_name: "models/option_chain" } do
  subject(:option_chain_model) { described_class }

  let(:valid_params) do
    {
      underlying_scrip: 13,
      underlying_seg: "IDX_I",
      expiry: "2025-02-06"
    }
  end

  before do
    DhanHQ.configure_with_env
  end

  it "fetches and filters option chain" do
    response = option_chain_model.fetch(valid_params)

    expect(response).to be_a(Hash)
    expect(response[:last_price]).to be > 0

    # Ensure strike prices retain their original format (strings)
    expect(response[:oc].keys).to all(be_a(String))

    # Ensure only valid strikes with last_price > 0 are included
    response[:oc].each_value do |strike_data|
      ce_last_price = strike_data.dig("ce", "last_price")
      pe_last_price = strike_data.dig("pe", "last_price")
      expect(ce_last_price).to be > 0 if strike_data.key?("ce")
      expect(pe_last_price).to be > 0 if strike_data.key?("pe")
    end
  end
end
