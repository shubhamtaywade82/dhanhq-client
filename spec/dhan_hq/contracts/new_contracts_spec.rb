# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require "spec_helper"
require "DhanHQ/contracts/pnl_based_exit_contract"
require "DhanHQ/contracts/user_ip_contract"

RSpec.describe DhanHQ::Contracts do
  describe DhanHQ::Contracts::PnlBasedExitContract do
    let(:contract) { described_class.new }

    it "requires at least one of profitValue or lossValue" do
      result = contract.call({})
      expect(result.success?).to be false
      expect(result.errors.to_h[:profitValue]).to include("at least one of profitValue or lossValue must be provided")
    end

    it "accepts valid values" do
      result = contract.call(profitValue: 100.0)
      expect(result.success?).to be true
    end
  end

  describe DhanHQ::Contracts::UserIpContract do
    let(:contract) { described_class.new }

    it "validates required fields" do
      result = contract.call({})
      expect(result.success?).to be false
      expect(result.errors.to_h.keys).to include(:ip, :ipFlag)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
