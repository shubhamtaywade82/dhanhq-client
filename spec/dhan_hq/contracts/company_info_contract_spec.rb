# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::CompanyInfoContract do
  let(:valid_params) do
    {
      security_id: "1333", exchange_segment: "NSE_EQ",
      instrument: "EQUITY", metrics: %w[CO RATIOS SHP]
    }
  end

  it "accepts a valid request" do
    expect(described_class.new.call(valid_params)).to be_success
  end

  it "rejects a non-numeric security id" do
    result = described_class.new.call(valid_params.merge(security_id: "RELIANCE"))

    expect(result.errors[:security_id]).not_to be_empty
  end

  it "rejects an unsupported segment" do
    result = described_class.new.call(valid_params.merge(exchange_segment: "NSE_FNO"))

    expect(result.errors[:exchange_segment]).not_to be_empty
  end

  it "rejects an empty metrics array" do
    result = described_class.new.call(valid_params.merge(metrics: []))

    expect(result.errors[:metrics]).not_to be_empty
  end

  it "rejects an unknown metric section" do
    result = described_class.new.call(valid_params.merge(metrics: %w[CO BALANCE_SHEET]))

    expect(result.errors[:metrics]).not_to be_empty
  end
end
