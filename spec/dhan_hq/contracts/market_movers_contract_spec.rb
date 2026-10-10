# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::MarketMoversContract do
  let(:valid_params) do
    {
      exchange_segment: "NSE_FNO", instrument: %w[OPTIDX],
      category: "HIGHEST_OI", expiry: "2026-10-29", limit: 10
    }
  end

  it "accepts a valid derivatives request" do
    expect(described_class.new.call(valid_params)).to be_success
  end

  it "accepts a valid equity request with universe instead of expiry" do
    result = described_class.new.call(
      exchange_segment: "NSE_EQ", instrument: %w[EQUITY],
      category: "PRICE_GAINERS", universe: "NIFTY_50", limit: 25
    )

    expect(result).to be_success
  end

  it "requires expiry for derivative instruments" do
    result = described_class.new.call(valid_params.except(:expiry))

    expect(result.errors[:expiry]).to include(/required when instrument includes options or futures/)
  end

  it "requires universe for EQUITY rankings" do
    result = described_class.new.call(
      exchange_segment: "NSE_EQ", instrument: %w[EQUITY],
      category: "PRICE_GAINERS", limit: 25
    )

    expect(result.errors[:universe]).to include(/required when instrument is EQUITY/)
  end

  it "rejects a limit above 100" do
    result = described_class.new.call(valid_params.merge(limit: 101))

    expect(result.errors[:limit]).not_to be_empty
  end

  it "rejects a malformed expiry date" do
    result = described_class.new.call(valid_params.merge(expiry: "29-10-2026"))

    expect(result.errors[:expiry]).not_to be_empty
  end

  it "rejects an unknown category" do
    result = described_class.new.call(valid_params.merge(category: "MOST_ACTIVE"))

    expect(result.errors[:category]).not_to be_empty
  end

  it "rejects an unknown universe" do
    result = described_class.new.call(valid_params.merge(universe: "NASDAQ"))

    expect(result.errors[:universe]).not_to be_empty
  end
end
