# frozen_string_literal: true

# Proves the bang variants are purely additive: the non-bang methods keep the exact
# return values existing callers were written against, and the bang variants raise a
# single error type for the same failure.
RSpec.describe DhanHQ::Concerns::BangWrites do
  let(:order_params) do
    {
      transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "INTRADAY",
      order_type: "MARKET", validity: "DAY", security_id: "11536", quantity: 5
    }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
    stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "DhanHQ::Models::Order" do
    context "when the API rejects the order" do
      before do
        stub_request(:post, "https://api.dhan.co/v2/orders")
          .to_return(status: 200, body: { orderStatus: "REJECTED" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "still returns nil from .place, unchanged for existing callers" do
        expect(DhanHQ::Models::Order.place(order_params)).to be_nil
      end

      it "raises OrderError from .place!" do
        expect { DhanHQ::Models::Order.place!(order_params) }
          .to raise_error(DhanHQ::OrderError, /Order\.place failed/)
      end

      it "raises something an existing rescue DhanHQ::Error handler catches" do
        expect { DhanHQ::Models::Order.place!(order_params) }.to raise_error(DhanHQ::Error)
      end
    end

    context "when the order is accepted" do
      before do
        stub_request(:post, "https://api.dhan.co/v2/orders")
          .to_return(status: 200, body: { orderId: "999", orderStatus: "TRANSIT" }.to_json,
                     headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.dhan.co/v2/orders/999")
          .to_return(status: 200, body: { orderId: "999", orderStatus: "PENDING", securityId: "11536" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns the same order from .place and .place!" do
        expect(DhanHQ::Models::Order.place(order_params).order_id).to eq("999")
        expect(DhanHQ::Models::Order.place!(order_params).order_id).to eq("999")
      end
    end

    describe "#cancel!" do
      subject(:order) { DhanHQ::Models::Order.new({ orderId: "999" }, skip_validation: true) }

      it "raises when the exchange did not cancel" do
        stub_request(:delete, "https://api.dhan.co/v2/orders/999")
          .to_return(status: 200, body: { orderStatus: "PENDING" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect(order.cancel).to be(false)
        expect { order.cancel! }.to raise_error(DhanHQ::OrderError, /Order#cancel failed/)
      end

      it "returns true when the exchange cancelled" do
        stub_request(:delete, "https://api.dhan.co/v2/orders/999")
          .to_return(status: 200, body: { orderStatus: "CANCELLED" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect(order.cancel!).to be(true)
      end
    end
  end

  describe "DhanHQ::Models::MultiOrder" do
    let(:legs) do
      [{ sequence: "1", transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
         order_type: "LIMIT", validity: "DAY", security_id: "11536", quantity: 1, price: 1500.0 }]
    end

    it "surfaces the ErrorObject's diagnostics when raising" do
      stub_request(:post, "https://api.dhan.co/v2/alerts/multi/orders")
        .to_return(status: 200, body: { errorMessage: "basket rejected" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(DhanHQ::Models::MultiOrder.place(legs)).to be_a(DhanHQ::ErrorObject)
      expect { DhanHQ::Models::MultiOrder.place!(legs) }
        .to raise_error(DhanHQ::OrderError, /basket rejected/)
    end
  end

  describe "DhanHQ::Models::GlobalStocks::Order" do
    it "raises from .place! while .place still returns an ErrorObject" do
      stub_request(:post, "https://api.dhan.co/v2/globalstocks/orders")
        .to_return(status: 200, body: { orderStatus: "REJECTED" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      params = { transaction_type: "BUY", order_type: "LIMIT", security_id: "AAPL",
                 quantity: 1.0, price: 180.0 }

      expect(DhanHQ::Models::GlobalStocks::Order.place(params)).to be_a(DhanHQ::ErrorObject)
      expect { DhanHQ::Models::GlobalStocks::Order.place!(params) }.to raise_error(DhanHQ::OrderError)
    end
  end

  describe "coverage of the write surface" do
    {
      "DhanHQ::Models::Order" => %i[place! create!],
      "DhanHQ::Models::SuperOrder" => %i[create!],
      "DhanHQ::Models::ForeverOrder" => %i[create!],
      "DhanHQ::Models::IcebergOrder" => %i[create!],
      "DhanHQ::Models::TwapOrder" => %i[create!],
      "DhanHQ::Models::AlertOrder" => %i[create! modify!],
      "DhanHQ::Models::PnlExit" => %i[configure! stop!],
      "DhanHQ::Models::MultiOrder" => %i[place!],
      "DhanHQ::Models::GlobalStocks::Order" => %i[place!]
    }.each do |class_name, methods|
      it "defines #{methods.join(", ")} on #{class_name}" do
        expect(Object.const_get(class_name)).to respond_to(*methods)
      end
    end

    %w[
      DhanHQ::Models::Order
      DhanHQ::Models::SuperOrder
      DhanHQ::Models::GlobalStocks::Order
    ].each do |class_name|
      it "defines #modify! and #cancel! on #{class_name}" do
        expect(Object.const_get(class_name).instance_methods).to include(:modify!, :cancel!)
      end
    end
  end
end
