# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Margin, vcr: {
  cassette_name: "models/margin",
  record: :once  # or :new_episodes, whichever mode suits your workflow
} do
  before do
    # Ensure the DhanHQ gem is configured with valid credentials from ENV
    DhanHQ.configure_with_env
  end

  describe ".calculate" do
    let(:params) do
      {
        # Adjust these parameters for a valid margin calculation in your account
        dhanClientId: ENV.fetch("CLIENT_ID", "FAKE_ID"),
        exchangeSegment: "NSE_EQ",
        transactionType: "BUY",
        productType: "CNC",
        securityId: "11536",       # Example Security ID (e.g. TCS)
        quantity: 10,
        price: 100.0
        # triggerPrice:  ... # only needed for STOP_LOSS orders
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
end
