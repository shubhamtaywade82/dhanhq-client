# frozen_string_literal: true

RSpec.describe DhanHQ::Models::LedgerEntry, vcr: {
  cassette_name: "models/ledger_entry",
  record: :once  # or :new_episodes, or whichever mode you prefer
} do
  before do
    # Ensure DhanHQ gem is configured with valid credentials.
    DhanHQ.configure_with_env
  end

  describe ".all" do
    # Provide some test date range that suits your account.
    let(:from_date) { "2024-07-01" }
    let(:to_date)   { "2024-07-31" }

    it "retrieves ledger entries for the given date range" do
      entries = described_class.all(from_date: from_date, to_date: to_date)
      expect(entries).to be_an(Array)

      # Each entry should be a LedgerEntry
      entries.each do |entry|
        expect(entry).to be_a(described_class)

        # Check typical fields from the API:
        expect(entry.dhan_client_id).to be_a(String).or be_nil
        expect(entry.narration).to be_a(String).or be_nil
        expect(entry.voucherdate).to be_a(String).or be_nil
        expect(entry.exchange).to be_a(String).or be_nil
        expect(entry.voucherdesc).to be_a(String).or be_nil
        expect(entry.vouchernumber).to be_a(String).or be_nil
        expect(entry.debit).to be_a(String).or be_nil
        expect(entry.credit).to be_a(String).or be_nil
        expect(entry.runbal).to be_a(String).or be_nil
      end
    end
  end
end
