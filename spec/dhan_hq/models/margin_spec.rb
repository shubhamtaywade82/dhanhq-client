# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Margin, vcr: {
  cassette_name: "models/margin",
  record: :once # or :new_episodes, whichever mode suits your workflow
} do
  before do
    # Ensure the DhanHQ gem is configured with valid credentials from ENV
    DhanHQ.configure_with_env
  end

  describe ".calculate" do
    let(:params) do
      {
        # Adjust these parameters for a valid margin calculation in your account
        dhan_client_id: ENV.fetch("CLIENT_ID", "FAKE_ID"),
        exchange_segment: "NSE_EQ",
        transaction_type: "BUY",
        product_type: "CNC",
        security_id: "11536", # Example Security ID (e.g. TCS)
        quantity: 10,
        price: 100.0
        # trigger_price:  ... # only needed for STOP_LOSS orders
      }
    end

    it "fetches margin requirements for a sample order" do
      margin = described_class.calculate(params)

      expect(margin).to be_a(described_class)

      # Check if certain fields are present or have valid values:
      expect(margin.total_margin).to be_a(Float).or be_nil
      expect(margin.span_margin).to be_a(Float).or be_nil
      expect(margin.exposure_margin).to be_a(Float).or be_nil
      expect(margin.available_balance).to be_a(Float).or be_nil
      expect(margin.variable_margin).to be_a(Float).or be_nil
      expect(margin.insufficient_balance).to be_a(Float).or be_nil
      expect(margin.brokerage).to be_a(Float).or be_nil
      expect(margin.leverage).to be_a(String).or be_nil

      # Optionally, you can also test the to_h method
      hash = margin.to_h
      expect(hash).to include(:total_margin, :span_margin, :exposure_margin)
    end
  end

  describe "validation" do
    let(:resource_double) { instance_double(DhanHQ::Resources::MarginCalculator) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "raises when required fields are missing", vcr: false do
      expect(resource_double).not_to receive(:calculate)

      expect do
        described_class.calculate({})
      end.to raise_error(DhanHQ::Error, /Validation Error/)
    end
  end

  describe "formatting" do
    let(:resource_double) { instance_double(DhanHQ::Resources::MarginCalculator) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "camelizes keys before posting", vcr: false do
      payload = {
        dhan_client_id: "1100003626",
        exchange_segment: "NSE_EQ",
        transaction_type: "BUY",
        product_type: "CNC",
        security_id: "1333",
        quantity: 1,
        price: 1400.0
      }

      expect(resource_double).to receive(:calculate) do |arg|
        expect(arg).to include(
          "dhanClientId" => "1100003626",
          "transactionType" => "BUY",
          "productType" => "CNC"
        )
        {}
      end

      allow(described_class).to receive(:new).and_return(instance_double(described_class))

      described_class.calculate(payload)
    end
  end

  describe "#to_h" do
    it "returns normalised attributes" do
      margin = described_class.new({ "totalMargin" => 10.0, "spanMargin" => 5.0 }, skip_validation: true)

      hash = margin.to_h
      expect(hash).to include(:total_margin, :span_margin)
    end
  end
end
