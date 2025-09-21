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

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::OptionChain) }
    let(:params) { { underlying_scrip: 13, underlying_seg: "IDX_I", expiry: "2025-02-06" } }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
      allow(described_class).to receive(:validate_params!).and_call_original
    end

    it "exposes the validation contract helpers" do
      expect(described_class.send(:validation_contract)).to be_a(DhanHQ::Contracts::OptionChainContract)
      instance = described_class.new({}, skip_validation: true)
      expect(instance.send(:validation_contract)).to be_a(DhanHQ::Contracts::OptionChainContract)
    end

    it "returns filtered strikes when status is success" do
      payload = {
        status: "success",
        data: {
          oc: {
            "100" => { "ce" => { "last_price" => "0" }, "pe" => { "last_price" => "0" } },
            "200" => { "ce" => { "last_price" => "5" }, "pe" => { "last_price" => "0" } }
          }
        }
      }
      allow(resource_double).to receive(:fetch).with(params).and_return(payload)

      result = described_class.fetch(params)
      expect(result[:oc].keys).to eq(["200"])
    end

    it "returns an empty hash when status is not success" do
      allow(resource_double).to receive(:fetch).and_return({ status: "error" })

      expect(described_class.fetch(params)).to eq({}.with_indifferent_access)
    end

    it "returns expiry list when status success" do
      allow(resource_double).to receive(:expirylist).with(params)
                                                    .and_return({ status: "success", data: %w[2025-02-06 2025-02-13] })

      expiries = described_class.fetch_expiry_list(params)
      expect(expiries).to eq(%w[2025-02-06 2025-02-13])
    end

    it "returns empty array when expiry list status not success" do
      allow(resource_double).to receive(:expirylist).and_return({ status: "error" })

      expect(described_class.fetch_expiry_list(params)).to eq([])
    end
  end
end
