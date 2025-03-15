# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Funds, vcr: { cassette_name: "models/funds" } do
  subject(:funds_model) { described_class }

  before do
    # Ensure we have credentials in ENV (CLIENT_ID, ACCESS_TOKEN) or
    # that DhanHQ.configure is being invoked properly.
    DhanHQ.configure_with_env
  end

  describe ".fetch" do
    it "retrieves the fund details and returns a Funds object" do
      result = funds_model.fetch

      # The method returns a DhanHQ::Models::Funds instance
      expect(result).to be_a(described_class)

      # Check that certain attributes exist and are numeric
      expect(result.availabel_balance).to be_a(Float)
      expect(result.utilized_amount).to be_a(Float)
      # etc...

      # Optionally, check that the numeric values are not negative, etc.
      expect(result.availabel_balance).to be >= 0
    end
  end

  describe ".balance" do
    it "returns only the available balance (float)" do
      bal = funds_model.balance
      expect(bal).to be_a(Float)
      expect(bal).to be >= 0
    end
  end
end