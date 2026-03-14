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
    expect(response[:strikes]).to be_an(Array)
    expect(response[:strikes]).to all(include(:strike, :call, :put))
    expect(
      response[:strikes].all? do |s|
        (s[:call].nil? || s.dig(:call, "last_price").to_f.positive?) &&
          (s[:put].nil? || s.dig(:put, "last_price").to_f.positive?)
      end
    ).to be true
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
          last_price: 24_500.0,
          oc: {
            "100" => { "ce" => { "last_price" => "0" }, "pe" => { "last_price" => "0" } },
            "200" => { "ce" => { "last_price" => "5" }, "pe" => { "last_price" => "0" } }
          }
        }
      }
      allow(resource_double).to receive(:fetch).with(params).and_return(payload)

      result = described_class.fetch(params)
      expect(result[:strikes].map { |s| s[:strike] }).to eq([200.0])
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

    it "validates required parameters for fetch" do
      expect { described_class.fetch({}) }.to raise_error(DhanHQ::Error, /Validation Error/)
      expect { described_class.fetch({ underlying_scrip: 13 }) }.to raise_error(DhanHQ::Error, /Validation Error/)
      expect do
        described_class.fetch({ underlying_scrip: 13,
                                underlying_seg: "IDX_I" })
      end.to raise_error(DhanHQ::Error, /Validation Error/)
    end

    it "validates required parameters for fetch_expiry_list" do
      expect { described_class.fetch_expiry_list({}) }.to raise_error(DhanHQ::Error, /Validation Error/)
      expect do
        described_class.fetch_expiry_list({ underlying_scrip: 13 })
      end.to raise_error(DhanHQ::Error, /Validation Error/)
    end

    it "validates expiry format for fetch" do
      invalid_params = { underlying_scrip: 13, underlying_seg: "IDX_I", expiry: "invalid-date" }
      expect { described_class.fetch(invalid_params) }.to raise_error(DhanHQ::Error, /Validation Error/)
    end

    it "accepts valid parameters for fetch_expiry_list without expiry" do
      valid_expiry_params = { underlying_scrip: 13, underlying_seg: "IDX_I" }
      allow(resource_double).to receive(:expirylist).with(valid_expiry_params)
                                                    .and_return({ status: "success", data: %w[2025-02-06] })

      expect { described_class.fetch_expiry_list(valid_expiry_params) }.not_to raise_error
    end
  end
end
