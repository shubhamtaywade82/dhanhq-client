# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::Orders do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/globalstocks/orders" }

  let(:valid_place_params) do
    {
      transaction_type: "BUY",
      order_type: "LIMIT",
      security_id: "AAPL",
      quantity: 1.0,
      price: 180.0
    }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises before touching the API on create" do
        expect { resource.create(valid_place_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError, /Live trading is disabled/)
      end

      it "raises before touching the API on update" do
        expect { resource.update("112111182198", valid_place_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end

      it "raises before touching the API on cancel" do
        expect { resource.cancel("112111182198") }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#create" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "POSTs a camelCased payload and returns the order status" do
      stub_request(:post, base)
        .with(body: hash_including("transactionType" => "BUY", "orderType" => "LIMIT",
                                   "securityId" => "AAPL", "quantity" => 1.0, "price" => 180.0))
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.create(valid_place_params)

      expect(response["orderId"]).to eq("112111182198")
      expect(response["orderStatus"]).to eq("TRANSIT")
    end

    it "injects dhanClientId into the payload" do
      stub_request(:post, base)
        .with(body: hash_including("dhanClientId" => DhanHQ.configuration.client_id))
        .to_return(status: 200, body: { orderId: "1", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.create(valid_place_params)

      expect(WebMock).to have_requested(:post, base)
        .with(body: hash_including("dhanClientId" => DhanHQ.configuration.client_id))
    end

    it "accepts an integer quantity by widening it to a float" do
      stub_request(:post, base)
        .to_return(status: 200, body: { orderId: "1", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { resource.create(valid_place_params.merge(quantity: 2)) }.not_to raise_error
    end

    it "accepts a fractional quantity" do
      stub_request(:post, base)
        .with(body: hash_including("quantity" => 0.5))
        .to_return(status: 200, body: { orderId: "1", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { resource.create(valid_place_params.merge(quantity: 0.5)) }.not_to raise_error
    end

    it "places an AMOUNT order with a dollar amount instead of a quantity" do
      stub_request(:post, base)
        .with(body: hash_including("orderType" => "AMOUNT", "amount" => 500.0))
        .to_return(status: 200, body: { orderId: "1", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.create(transaction_type: "BUY", order_type: "AMOUNT", security_id: "AAPL", amount: 500.0)

      expect(WebMock).to have_requested(:post, base).with(body: hash_including("amount" => 500.0))
    end

    it "rejects a LIMIT order without a price" do
      expect { resource.create(valid_place_params.except(:price)) }
        .to raise_error(DhanHQ::ValidationError, /price/)
    end

    it "rejects an AMOUNT order without an amount" do
      expect { resource.create(transaction_type: "BUY", order_type: "AMOUNT", security_id: "AAPL") }
        .to raise_error(DhanHQ::ValidationError, /amount/)
    end

    it "rejects a non-AMOUNT order without a quantity" do
      expect { resource.create(valid_place_params.except(:quantity)) }
        .to raise_error(DhanHQ::ValidationError, /quantity/)
    end

    it "rejects a domestic order type that the US book does not accept" do
      expect { resource.create(valid_place_params.merge(order_type: "BOGUS")) }
        .to raise_error(DhanHQ::ValidationError, /order_type/)
    end

    it "rejects a stop loss above entry on a BUY" do
      expect { resource.create(valid_place_params.merge(stop_loss_price: 200.0)) }
        .to raise_error(DhanHQ::ValidationError, /stop_loss_price/)
    end
  end

  describe "#update" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "PUTs to the order path" do
      stub_request(:put, "#{base}/112111182198")
        .with(body: hash_including("orderType" => "LIMIT", "price" => 185.0))
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "MODIFIED" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.update("112111182198", valid_place_params.merge(price: 185.0))

      expect(response["orderStatus"]).to eq("MODIFIED")
    end

    it "validates the leg name" do
      expect { resource.update("1", valid_place_params.merge(leg_name: "NOPE")) }
        .to raise_error(DhanHQ::ValidationError, /leg_name/)
    end
  end

  describe "#cancel" do
    before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true")) }

    it "DELETEs the order path" do
      stub_request(:delete, "#{base}/112111182198")
        .to_return(status: 200, body: { orderId: "112111182198", orderStatus: "CANCELLED" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.cancel("112111182198")

      expect(response["orderStatus"]).to eq("CANCELLED")
    end
  end

  describe "reads" do
    it "#all fetches the order book" do
      stub_request(:get, base)
        .to_return(status: 200, body: [{ orderId: "1", securityId: "AAPL" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(resource.all.first["securityId"]).to eq("AAPL")
    end

    it "#find fetches a single order" do
      stub_request(:get, "#{base}/1")
        .to_return(status: 200, body: { orderId: "1", securityId: "AAPL" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(resource.find("1")["orderId"]).to eq("1")
    end

    it "does not require LIVE_TRADING" do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false"))
      stub_request(:get, base).to_return(status: 200, body: [].to_json,
                                         headers: { "Content-Type" => "application/json" })

      expect { resource.all }.not_to raise_error
    end
  end
end
