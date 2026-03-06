# frozen_string_literal: true

require "spec_helper"
require "DhanHQ/contracts/pnl_based_exit_contract"

RSpec.describe DhanHQ::Contracts::PnlBasedExitContract do
  let(:contract) { described_class.new }

  it "requires at least one of profitValue or lossValue" do
    result = contract.call({})
    expect(result.success?).to be false
    expect(result.errors.to_h[:profitValue]).to include("at least one of profitValue or lossValue must be provided")
  end

  it "accepts valid values with profitValue only" do
    expect(contract.call(profitValue: 100.0).success?).to be true
  end
end
