# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Order do
  let(:valid_attributes) do
    { dhanClientId: "12345", transactionType: "BUY", productType: "INTRADAY", securityId: "11536", quantity: 10,
      price: 300.50 }
  end

  it "places an order successfully" do
    order = described_class.new(valid_attributes)
    expect(order.valid?).to be true

    placed_order = order.place
    expect(placed_order).to be_a(described_class)
    expect(placed_order.id).not_to be_nil
  end
end
