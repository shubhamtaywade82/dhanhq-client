# frozen_string_literal: true

require "spec_helper"

# Cross-checks the gem's hand-maintained constant enums against the vendored
# contract's enums. The constants remain the semantic layer (the dry-validation
# contracts use them); this spec exists so neither side can drift silently.
#
# Known, documented deltas are declared explicitly — an undeclared delta fails.
RSpec.describe "enum parity between constants and the vendored contract" do
  let(:schemas) { DhanHQ::Contract::Registry.live_schemas }

  it "matches OrderRequest#exchangeSegment to Constants::EXCHANGE_SEGMENTS" do
    spec_enum = schemas.dig("OrderRequest", "properties", "exchangeSegment", "enum")

    # Overlay 0005 reconciled the vendor enum (6 values, missing the index and
    # currency segments) with the published annexure table.
    expect(spec_enum).to match_array(DhanHQ::Constants::EXCHANGE_SEGMENTS.map(&:to_s))
  end

  it "matches OrderRequest#transactionType" do
    spec_enum = schemas.dig("OrderRequest", "properties", "transactionType", "enum")

    expect(DhanHQ::Constants::TRANSACTION_TYPES.map(&:to_s)).to match_array(spec_enum)
  end

  it "matches OrderRequest#orderType" do
    spec_enum = schemas.dig("OrderRequest", "properties", "orderType", "enum")
    gem_values = DhanHQ::Constants::ORDER_TYPES.map(&:to_s)

    missing_from_spec = gem_values - spec_enum
    # The spec enum omits the derivable order-type variants the API documents
    # in prose (e.g. STOP_LOSS_MARKET is present; provisional variants are
    # carried by the constants for forward-compatibility). Declared here:
    allowed_delta = %w[]

    expect(missing_from_spec - allowed_delta).to be_empty
  end

  it "matches OrderRequest#validity" do
    spec_enum = schemas.dig("OrderRequest", "properties", "validity", "enum")

    expect(DhanHQ::Constants::VALIDITY_TYPES.map(&:to_s)).to match_array(spec_enum)
  end

  it "keeps the sandbox document's enums consistent with the live document" do
    live_enum = schemas.dig("OrderRequest", "properties", "transactionType", "enum")
    sandbox_doc = DhanHQ::Contract::Registry.sandbox_doc
    sandbox_enum = sandbox_doc.dig("components", "schemas", "OrderRequest",
                                   "properties", "transactionType", "enum")

    expect(sandbox_enum).to eq(live_enum)
  end
end
