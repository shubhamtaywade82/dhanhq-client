# frozen_string_literal: true

RSpec.describe DhanHQ::Risk::Limits do
  after { DhanHQ.configuration.risk_limits = {} }

  it "falls back to the check's default when unset" do
    expect(described_class.value(:max_quantity, 10)).to eq(10)
  end

  it "returns the configured value" do
    DhanHQ.configuration.risk_limits = { "max_quantity" => "1800" }

    expect(described_class.value(:max_quantity, 10)).to eq(1800)
  end

  it "lets a configured quantity cap admit a full F&O lot" do
    DhanHQ.configuration.risk_limits = { max_quantity: 75, max_notional: 50_000 }

    expect { DhanHQ::Risk::Checks::Quantity.run!(args: { "quantity" => 75, "price" => 120.0 }) }.not_to raise_error
  end

  it "reads DHAN_RISK_* variables" do
    stub_const("ENV", ENV.to_h.merge("DHAN_RISK_MAX_OPEN_POSITIONS" => "5"))

    expect(described_class.from_env).to eq(max_open_positions: 5)
  end

  it "rejects unknown names and non-positive values" do
    expect { described_class.coerce(foo: 1) }.to raise_error(ArgumentError, /unknown risk limit/)
    expect { described_class.coerce(max_quantity: 0) }.to raise_error(ArgumentError, /must be positive/)
    expect { described_class.coerce(max_quantity: "ten") }.to raise_error(ArgumentError, /must be a number/)
  end
end
