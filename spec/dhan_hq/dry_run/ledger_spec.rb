# frozen_string_literal: true

RSpec.describe DhanHQ::DryRun::Ledger do
  subject(:ledger) { described_class.new(max_entries: 3) }

  it "stores and retrieves a record" do
    ledger.record("DRYRUN-1", { "orderId" => "DRYRUN-1" })

    expect(ledger.fetch("DRYRUN-1")).to eq({ "orderId" => "DRYRUN-1" })
  end

  it "returns nil for an unknown id" do
    expect(ledger.fetch("DRYRUN-MISSING")).to be_nil
  end

  it "evicts the oldest records past the cap so a long rehearsal stays bounded" do
    1.upto(5) { |i| ledger.record("DRYRUN-#{i}", { "n" => i }) }

    expect(ledger.size).to eq(3)
    expect(ledger.fetch("DRYRUN-1")).to be_nil
    expect(ledger.fetch("DRYRUN-5")).to eq({ "n" => 5 })
  end

  it "refreshes an existing id rather than double-counting it" do
    ledger.record("DRYRUN-1", { "n" => 1 })
    ledger.record("DRYRUN-1", { "n" => 2 })

    expect(ledger.size).to eq(1)
    expect(ledger.fetch("DRYRUN-1")).to eq({ "n" => 2 })
  end

  it "clears every record" do
    ledger.record("DRYRUN-1", {})
    ledger.clear

    expect(ledger.size).to eq(0)
  end

  it "exposes a shared process-wide instance" do
    shared = described_class.instance
    shared.record("DRYRUN-SHARED", { "n" => 1 })

    expect(described_class.instance.fetch("DRYRUN-SHARED")).to eq({ "n" => 1 })
  ensure
    described_class.instance.clear
  end
end
