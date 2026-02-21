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
        dhan_client_id: ENV.fetch("DHAN_CLIENT_ID", "FAKE_ID"),
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
    end

    it "returns valid margin data types" do
      margin = described_class.calculate(params)

      expect(margin.total_margin).to be_a(Float).or be_nil
      expect(margin.span_margin).to be_a(Float).or be_nil
      expect(margin.exposure_margin).to be_a(Float).or be_nil
      expect(margin.available_balance).to be_a(Float).or be_nil
    end

    it "returns additional margin fields" do
      margin = described_class.calculate(params)

      expect(margin.variable_margin).to be_a(Float).or be_nil
      expect(margin.insufficient_balance).to be_a(Float).or be_nil
      expect(margin.brokerage).to be_a(Float).or be_nil
      expect(margin.leverage).to be_a(String).or be_nil
    end

    it "provides to_h method with normalized attributes" do
      margin = described_class.calculate(params)

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
      allow(resource_double).to receive(:calculate)

      expect do
        described_class.calculate({})
      end.to raise_error(DhanHQ::Error, /Validation Error/)

      expect(resource_double).not_to have_received(:calculate)
    end
  end

  describe "formatting" do
    let(:resource_double) { instance_double(DhanHQ::Resources::MarginCalculator) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "camelizes keys before posting", vcr: false do # rubocop:disable RSpec/ExampleLength
      payload = {
        dhan_client_id: "1100003626",
        exchange_segment: "NSE_EQ",
        transaction_type: "BUY",
        product_type: "CNC",
        security_id: "1333",
        quantity: 1,
        price: 1400.0
      }

      allow(resource_double).to receive(:calculate) do |arg|
        expect(arg).to include(
          "dhanClientId" => "1100003626",
          "transactionType" => "BUY",
          "productType" => "CNC"
        )
        {}
      end

      allow(described_class).to receive(:new).and_return(instance_double(described_class))

      described_class.calculate(payload)

      expect(resource_double).to have_received(:calculate)
    end
  end

  describe ".calculate_multi" do
    let(:resource_double) { instance_double(DhanHQ::Resources::MarginCalculator) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    it "camelizes keys and delegates to resource.calculate_multi", vcr: false do # rubocop:disable RSpec/ExampleLength
      params = {
        include_position: true,
        include_order: true,
        dhan_client_id: "1100003626",
        scrip_list: [
          { exchange_segment: "NSE_EQ", transaction_type: "BUY",
            quantity: 100, product_type: "CNC", security_id: "1333", price: 1428.0 }
        ]
      }

      allow(resource_double).to receive(:calculate_multi) do |arg|
        expect(arg).to include("includePosition" => true, "includeOrder" => true)
        { "total_margin" => "150000.00", "hedge_benefit" => "" }
      end

      result = described_class.calculate_multi(params)
      expect(result).to include("total_margin" => "150000.00")
      expect(resource_double).to have_received(:calculate_multi)
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
