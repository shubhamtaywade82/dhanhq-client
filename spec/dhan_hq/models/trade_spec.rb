# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Trade do
  subject(:trade_model) { described_class }

  before do
    DhanHQ.configure_with_env
  end

  describe ".today" do
    it "fetches trades for the current day", vcr: { cassette_name: "models/trade_today" } do
      trades = trade_model.today

      expect(trades).to be_an(Array)
      # NOTE: trades might be empty if no trades exist for the day
      if trades.any?
        first_trade = trades.first
        expect(first_trade).to be_a(described_class)
        expect(first_trade.order_id).not_to be_nil
        expect(first_trade.traded_quantity).to be_an(Integer).or be_a(Float)
        expect(first_trade.traded_price).to be_an(Float)
      end
    end
  end

  describe ".find_by_order_id" do
    let(:order_id) { "123456789" }

    it "retrieves trade details for the order", vcr: { cassette_name: "models/trade_find" } do
      trade = trade_model.find_by_order_id(order_id)

      expect(trade).to be_a(described_class).or be_nil
    end

    it "validates order_id parameter" do
      expect { trade_model.find_by_order_id("") }
        .to raise_error(DhanHQ::ValidationError, /Invalid order_id/)

      expect { trade_model.find_by_order_id(nil) }
        .to raise_error(DhanHQ::ValidationError, /Invalid order_id/)
    end
  end

  describe ".history" do
    let(:from_date) { "2024-12-02" }
    let(:to_date)   { "2024-12-31" }
    let(:page)      { 0 }

    it "fetches trades in the given date range and page", vcr: { cassette_name: "models/trade_history" } do
      trades = trade_model.history(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      expect(trades).to be_an(Array)
    end

    it "returns valid trade objects when trades exist", vcr: { cassette_name: "models/trade_history" } do
      trades = trade_model.history(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      if trades.any?
        first_trade = trades.first
        expect(first_trade).to be_a(described_class)
        expect(first_trade.order_id).not_to be_nil
        expect(first_trade.traded_quantity).to be_an(Integer).or be_a(Float)
        expect(first_trade.traded_price).to be_an(Float)
      else
        expect(trades.size).to eq(0)
      end
    end

    it "validates date parameters" do
      # Invalid date format
      expect { trade_model.history(from_date: "invalid", to_date: "2024-12-31") }
        .to raise_error(DhanHQ::ValidationError, /must be in YYYY-MM-DD format/)

      # Invalid date range (from_date after to_date)
      expect { trade_model.history(from_date: "2024-12-31", to_date: "2024-12-02") }
        .to raise_error(DhanHQ::ValidationError, /from_date must be before to_date/)

      # Invalid page number
      expect { trade_model.history(from_date: "2024-12-02", to_date: "2024-12-31", page: -1) }
        .to raise_error(DhanHQ::ValidationError, /Invalid parameters/)
    end
  end

  describe ".all" do
    let(:from_date) { "2024-12-02" }
    let(:to_date)   { "2024-12-31" }

    it "is an alias for history method" do
      expect(trade_model.method(:all)).to eq(trade_model.method(:history))
    end
  end

  describe "instance methods" do
    let(:trade_data) do
      {
        "dhanClientId" => "1000000009",
        "orderId" => "112111182045",
        "exchangeOrderId" => "15112111182045",
        "exchangeTradeId" => "15112111182045",
        "transactionType" => "BUY",
        "exchangeSegment" => "NSE_EQ",
        "productType" => "INTRADAY",
        "orderType" => "LIMIT",
        "tradingSymbol" => "TCS",
        "securityId" => "11536",
        "tradedQuantity" => 40,
        "tradedPrice" => 3345.8,
        "createTime" => "2021-03-10 11:20:06",
        "updateTime" => "2021-11-25 17:35:12",
        "exchangeTime" => "2021-11-25 17:35:12",
        "drvExpiryDate" => nil,
        "drvOptionType" => nil,
        "drvStrikePrice" => 0.0,
        "instrument" => "EQUITY",
        "sebiTax" => 0.0004,
        "stt" => 0,
        "brokerageCharges" => 0,
        "serviceTax" => 0.0025,
        "exchangeTransactionCharges" => 0.0135,
        "stampDuty" => 0
      }
    end

    let(:trade) { described_class.new(trade_data, skip_validation: true) }

    describe "transaction type helpers" do
      it "identifies buy trades" do
        expect(trade.buy?).to be true
        expect(trade.sell?).to be false
      end

      it "identifies sell trades" do
        trade_data["transactionType"] = "SELL"
        sell_trade = described_class.new(trade_data, skip_validation: true)

        expect(sell_trade.sell?).to be true
        expect(sell_trade.buy?).to be false
      end
    end

    describe "instrument type helpers" do
      it "identifies equity trades" do
        expect(trade.equity?).to be true
        expect(trade.derivative?).to be false
      end

      it "identifies derivative trades" do
        trade_data["instrument"] = "DERIVATIVES"
        derivative_trade = described_class.new(trade_data, skip_validation: true)

        expect(derivative_trade.derivative?).to be true
        expect(derivative_trade.equity?).to be false
      end
    end

    describe "option type helpers" do
      it "identifies call options" do
        trade_data["drvOptionType"] = "CALL"
        call_trade = described_class.new(trade_data, skip_validation: true)

        expect(call_trade.option?).to be true
        expect(call_trade.call_option?).to be true
        expect(call_trade.put_option?).to be false
      end

      it "identifies put options" do
        trade_data["drvOptionType"] = "PUT"
        put_trade = described_class.new(trade_data, skip_validation: true)

        expect(put_trade.option?).to be true
        expect(put_trade.put_option?).to be true
        expect(put_trade.call_option?).to be false
      end
    end

    describe "calculation methods" do
      it "calculates total trade value" do
        expected_value = 40 * 3345.8
        expect(trade.total_value).to eq(expected_value)
      end

      it "calculates total charges" do
        expected_charges = 0.0004 + 0 + 0 + 0.0025 + 0.0135 + 0
        expect(trade.total_charges).to eq(expected_charges)
      end

      it "calculates net trade value" do
        expected_net = trade.total_value - trade.total_charges
        expect(trade.net_value).to eq(expected_net)
      end
    end
  end

  describe "unit tests" do
    let(:tradebook_resource) { instance_double(DhanHQ::Resources::Trades) }
    let(:statements_resource) { instance_double(DhanHQ::Resources::Statements) }

    before do
      described_class.instance_variable_set(:@tradebook_resource, nil)
      described_class.instance_variable_set(:@statements_resource, nil)
      allow(described_class).to receive_messages(
        tradebook_resource: tradebook_resource,
        statements_resource: statements_resource
      )
    end

    describe ".today" do
      it "maps responses to models" do
        allow(tradebook_resource).to receive(:all).and_return([{ "orderId" => "OID1" }])

        trades = described_class.today
        expect(trades.first.order_id).to eq("OID1")
      end

      it "returns empty array for non-array responses" do
        allow(tradebook_resource).to receive(:all).and_return("unexpected")

        expect(described_class.today).to eq([])
      end
    end

    describe ".find_by_order_id" do
      it "returns nil when response empty" do
        allow(tradebook_resource).to receive(:find).and_return([])

        expect(described_class.find_by_order_id("OID1")).to be_nil
      end

      it "unwraps array payload" do
        allow(tradebook_resource).to receive(:find).and_return([{ "orderId" => "OID1" }])

        trade = described_class.find_by_order_id("OID1")
        expect(trade.order_id).to eq("OID1")
      end

      it "handles hash response" do
        allow(tradebook_resource).to receive(:find).and_return({ "orderId" => "OID1" })

        trade = described_class.find_by_order_id("OID1")
        expect(trade.order_id).to eq("OID1")
      end
    end

    describe ".history" do
      it "returns models when response is array" do
        allow(statements_resource).to receive(:trade_history).and_return([{ "orderId" => "OID1" }])

        trades = described_class.history(from_date: "2024-01-01", to_date: "2024-01-02")
        expect(trades.first).to be_a(described_class)
      end

      it "returns [] for non arrays" do
        allow(statements_resource).to receive(:trade_history).and_return("unexpected")

        expect(described_class.history(from_date: "2024-01-01", to_date: "2024-01-02")).to eq([])
      end
    end
  end
end
