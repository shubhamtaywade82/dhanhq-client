# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Holding, vcr: {
  cassette_name: "models/holdings",
  record: :once
} do
  before do
    # Make sure your DhanHQ gem is configured with CLIENT_ID and ACCESS_TOKEN
    DhanHQ.configure_with_env
  end

  describe ".all" do
    it "fetches all holdings" do
      holdings = described_class.all
      expect(holdings).to be_an(Array)

      # At least check if we got an array of DhanHQ::Models::Holding
      holdings.each do |holding|
        expect(holding).to be_a(described_class)

        # Optionally check some attributes you expect:
        expect(holding.security_id).to be_a(String)
        expect(holding.trading_symbol).to be_a(String).or be_nil
        expect(holding.exchange).to be_a(String).or be_nil
      end
    end
  end
end
