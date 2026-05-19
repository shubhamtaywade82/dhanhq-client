# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::OptionChainExpiryListContract do
  let(:valid_params) { { underlying_scrip: 13, underlying_seg: "IDX_I" } }

  it "passes without expiry" do
    result = described_class.new.call(valid_params)
    expect(result.success?).to be true
  end

  it "rejects invalid segment" do
    result = described_class.new.call(valid_params.merge(underlying_seg: "INVALID"))
    expect(result.failure?).to be true
    expect(result.errors[:underlying_seg]).not_to be_empty
  end
end
