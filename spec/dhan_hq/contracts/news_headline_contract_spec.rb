# frozen_string_literal: true

RSpec.describe DhanHQ::Contracts::NewsHeadlineContract do
  let(:valid_params) { { categories: %w[ALL], limit: 10 } }

  it "accepts a valid request" do
    expect(described_class.new.call(valid_params)).to be_success
  end

  it "accepts multiple categories with scoping and stock filters" do
    result = described_class.new.call(
      categories: %w[COMPANIES TECHNOLOGY], limit: 50,
      universe: "PORTFOLIO", stock_list: %w[1333 11536]
    )

    expect(result).to be_success
  end

  it "rejects an empty categories array" do
    result = described_class.new.call(valid_params.merge(categories: []))

    expect(result.errors[:categories]).not_to be_empty
  end

  it "rejects an unknown category" do
    result = described_class.new.call(valid_params.merge(categories: %w[GOSSIP]))

    expect(result.errors[:categories]).not_to be_empty
  end

  it "rejects a limit above 50" do
    result = described_class.new.call(valid_params.merge(limit: 51))

    expect(result.errors[:limit]).not_to be_empty
  end

  it "rejects an unknown universe" do
    result = described_class.new.call(valid_params.merge(universe: "EVERYTHING"))

    expect(result.errors[:universe]).not_to be_empty
  end
end
