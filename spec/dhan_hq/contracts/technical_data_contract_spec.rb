# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::TechnicalDataContract do
  let(:valid_params) do
    {
      security_id: "1333", exchange_segment: "NSE_EQ", instrument: "EQUITY",
      timeframe: "D", indicators: %w[SMA_20 RSI_14 MACD_HIST]
    }
  end

  it "accepts a valid request" do
    expect(described_class.new.call(valid_params)).to be_success
  end

  it "accepts index instruments on IDX_I" do
    result = described_class.new.call(
      valid_params.merge(exchange_segment: "IDX_I", instrument: "INDEX")
    )

    expect(result).to be_success
  end

  it "rejects an unknown timeframe" do
    result = described_class.new.call(valid_params.merge(timeframe: "60"))

    expect(result.errors[:timeframe]).not_to be_empty
  end

  it "rejects an unknown indicator" do
    result = described_class.new.call(valid_params.merge(indicators: %w[SMA_20 NOT_REAL]))

    expect(result.errors[:indicators]).not_to be_empty
  end

  it "rejects a non-numeric security id" do
    result = described_class.new.call(valid_params.merge(security_id: 13.33))

    expect(result.errors[:security_id]).not_to be_empty
  end

  it "rejects an unsupported segment" do
    result = described_class.new.call(valid_params.merge(exchange_segment: "MCX_COMM"))

    expect(result.errors[:exchange_segment]).not_to be_empty
  end
end
