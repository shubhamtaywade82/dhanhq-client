# frozen_string_literal: true

# End-to-end: model -> resource -> OrderAudit -> Risk::Pipeline -> HTTP, with the
# real checks. Guards the regressions where param key style decided which checks
# ran (Symbol keys failed "Quantity must be > 0"; camelCase keys hid order_type,
# product_type and security_id from every check).
# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DhanHQ::Risk::Pipeline do
  let(:live) { "https://api.dhan.co/v2" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:accepted) { { status: 200, body: { orderId: "1", orderStatus: "PENDING" }.to_json, headers: json } }
  let(:positions) { [] }
  let(:open_market) { Time.new(2026, 10, 12, 11, 0, 0, "+05:30") }

  let(:option_leg) do
    { transaction_type: "BUY", exchange_segment: "NSE_FNO", product_type: "INTRADAY", security_id: "52175",
      quantity: 75, price: 120.0 }
  end

  before do
    stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, /ipify/).to_return(body: "1.2.3.4")
    allow(Time).to receive(:now).and_return(open_market)
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(FakeInstrument.build)
    allow(DhanHQ::Models::Position).to receive(:all) { positions }
    allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(double("funds", available_balance: 1_000_000))
    stub_request(:post, "#{live}/orders").to_return(accepted)
    stub_request(:post, "#{live}/super/orders").to_return(accepted)
    stub_request(:get, "#{live}/orders/1").to_return(accepted)
    DhanHQ.configuration.risk_limits = { max_quantity: 1_800, max_notional: 250_000 }
  end

  after do
    DhanHQ.configuration.risk_limits = {}
    DhanHQ::Utils::NetworkInspector.reset_cache!
  end

  describe ".run! on real order paths" do
    it "places a super order (bracket) for one option lot" do
      order = DhanHQ::Models::SuperOrder.create(option_leg.merge(order_type: "LIMIT", target_price: 150.0,
                                                                 stop_loss_price: 100.0, trailing_jump: 1.0))

      expect(WebMock).to have_requested(:post, "#{live}/super/orders")
      expect(order.order_id).to eq("1")
    end

    it "places a stop-loss order for one option lot" do
      DhanHQ::Models::Order.place(option_leg.merge(order_type: "STOP_LOSS", trigger_price: 121.0, validity: "DAY"))

      expect(WebMock).to have_requested(:post, "#{live}/orders")
    end

    it "still enforces the configured caps on new exposure" do
      DhanHQ.configuration.risk_limits = { max_quantity: 50 }

      expect do
        DhanHQ::Models::Order.place(option_leg.merge(order_type: "LIMIT", validity: "DAY"))
      end.to raise_error(DhanHQ::RiskViolation, "Quantity exceeds limit")
      expect(WebMock).not_to have_requested(:post, "#{live}/orders")
    end

    context "when the account is past its daily loss limit" do
      let(:positions) do
        [double("position", security_id: "52175", exchange_segment: "NSE_FNO", product_type: "INTRADAY",
                            trading_symbol: nil, net_qty: 75, cost_price: 120.0, realized_profit: 0,
                            unrealized_profit: -60_000)]
      end

      it "blocks a new entry" do
        expect do
          DhanHQ::Models::Order.place(option_leg.merge(security_id: "99999", order_type: "LIMIT", validity: "DAY"))
        end.to raise_error(DhanHQ::RiskViolation, /Daily loss limit/)
      end

      it "lets the stop-out through" do
        DhanHQ::Models::Order.place(option_leg.except(:price).merge(transaction_type: "SELL", trigger_price: 100.0,
                                                                    order_type: "STOP_LOSS_MARKET", validity: "DAY"))

        expect(WebMock).to have_requested(:post, "#{live}/orders")
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
