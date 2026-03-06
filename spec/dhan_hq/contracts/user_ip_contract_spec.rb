# frozen_string_literal: true

require "spec_helper"
require "DhanHQ/contracts/user_ip_contract"

RSpec.describe DhanHQ::Contracts::UserIpContract do
  let(:contract) { described_class.new }

  it "validates required fields ip and ipFlag" do
    result = contract.call({})
    expect(result.success?).to be false
    expect(result.errors.to_h.keys).to include(:ip, :ipFlag)
  end
end
