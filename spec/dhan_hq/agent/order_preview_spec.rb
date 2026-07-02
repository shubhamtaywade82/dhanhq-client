# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::OrderPreview do
  let(:params) do
    {
      transaction_type: "BUY",
      exchange_segment: "NSE_EQ",
      product_type: "INTRADAY",
      order_type: "MARKET",
      validity: "DAY",
      security_id: "2885",
      quantity: 1,
      correlation_id: "agent-test-1"
    }
  end

  it "returns a valid dry-run summary without placing an order" do
    preview = described_class.new(params).to_h

    expect(preview[:valid]).to be(true)
    expect(preview[:summary]).to include("BUY 1 of NSE_EQ:2885")
    expect(preview[:requires]).to include("LIVE_TRADING")
  end
end
