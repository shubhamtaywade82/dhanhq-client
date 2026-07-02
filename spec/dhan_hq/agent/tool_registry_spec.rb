# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::ToolRegistry do
  it "lists MCP-ready tool metadata" do
    names = described_class.list.map { |tool| tool[:name] }

    expect(names).to include("dhan_search_instruments", "dhan_order_preview", "dhan_place_order")
  end

  it "executes order preview with read-only order scope" do
    policy = DhanHQ::Agent::Policy.new(scopes: ["orders:read"])

    result = described_class.execute(
      "dhan_order_preview",
      {
        "transaction_type" => "BUY",
        "exchange_segment" => "NSE_EQ",
        "product_type" => "INTRADAY",
        "order_type" => "MARKET",
        "validity" => "DAY",
        "security_id" => "2885",
        "quantity" => 1,
        "correlation_id" => "agent-test-2"
      },
      policy: policy
    )

    expect(result[:valid]).to be(true)
  end
end
