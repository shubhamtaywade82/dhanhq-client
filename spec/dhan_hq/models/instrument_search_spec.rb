# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Instrument do
  it "searches instruments and returns SearchResult models" do
    allow(described_class).to receive(:by_segment).with("NSE_EQ").and_return([
      described_class.new(
        {
          security_id: "2885",
          symbol_name: "RELIANCE",
          display_name: "Reliance Industries",
          exchange_segment: "NSE_EQ"
        },
        skip_validation: true
      )
    ])

    results = described_class.search("reliance", segments: ["NSE_EQ"])

    expect(results.first).to be_a(DhanHQ::Models::SearchResult)
    expect(results.first.security_id).to eq("2885")
  end
end
