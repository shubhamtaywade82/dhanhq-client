# frozen_string_literal: true

require "spec_helper"

# Sandbox connectivity: hits real sandbox when VCR has no cassette (record: :new_episodes).
# In CI, either commit cassettes for these examples or run with DHAN_SANDBOX + credentials
# when recording. Locally, use VCR_RECORD=new_episodes (or all) with sandbox credentials to
# record or re-record. General suite forces DHAN_SANDBOX=false so this spec is isolated.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "Sandbox Connectivity", vcr: { record: :new_episodes } do
  before do
    # Clear memoized resources to ensure fresh Client initialization with new config
    DhanHQ::Models::Profile.instance_variable_set(:@api, nil)
    DhanHQ::Models::Funds.instance_variable_set(:@api, nil)

    DhanHQ.configure_with_env
    # Force sandbox mode for this spec
    DhanHQ.configuration.sandbox = true
  end

  it "successfully retrieves the user profile" do
    profile = DhanHQ::Models::Profile.fetch
    expect(profile).to be_a(DhanHQ::Models::Profile)
    expect(profile.dhan_client_id).to eq(ENV.fetch("DHAN_CLIENT_ID", nil))
  end

  it "successfully retrieves funds" do
    funds = DhanHQ::Models::Funds.fetch
    expect(funds).to be_a(DhanHQ::Models::Funds)
  end
end
# rubocop:enable RSpec/DescribeClass
