# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::Policy do
  it "defaults to read-only scopes from env helper" do
    ENV.delete("DHANHQ_AGENT_SCOPES")

    policy = described_class.from_env

    expect(policy).to be_allow("portfolio:read")
    expect(policy).not_to be_allow("orders:write")
  end

  it "blocks write scopes unless both write env flags are enabled" do
    policy = described_class.new(scopes: ["orders:write"])
    ENV.delete("DHANHQ_MCP_ENABLE_WRITES")
    ENV.delete("LIVE_TRADING")

    expect { policy.require_write!("orders:write") }.to raise_error(DhanHQ::LiveTradingDisabledError)
  end
end
