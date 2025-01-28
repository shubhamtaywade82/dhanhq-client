# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::OptionChain do
  let(:option_chain) { described_class.new }

  let(:option_chain_params) do
    {
      UnderlyingScrip: 13,
      UnderlyingSeg: "IDX_I",
      Expiry: "2025-01-30"
    }
  end

  let(:expiry_list_params) do
    {
      UnderlyingScrip: 13,
      UnderlyingSeg: "IDX_I"
    }
  end

  before do
    DhanHQ.configure_with_env
  end

  describe "#fetch_option_chain" do
    it "fetches the option chain data successfully", :vcr do
      VCR.use_cassette("resources/option_chain") do
        response = option_chain.fetch_option_chain(option_chain_params)
        expect(response["data"]["last_price"]).to eq(22_952.94921875)
        expect(response["data"]["oc"]["22900.000000"]["ce"]["last_price"]).to eq(186.2)
        expect(response["data"]["oc"]["22900.000000"]["pe"]["last_price"]).to eq(105.4)
      end
    end
  end

  describe "#fetch_expiry_list" do
    it "fetches the expiry list successfully", :vcr do
      VCR.use_cassette("resources/expiry_list") do
        response = option_chain.fetch_expiry_list(expiry_list_params)
        expect(response["data"]).to include("2025-01-30", "2025-02-13")
      end
    end
  end
end
