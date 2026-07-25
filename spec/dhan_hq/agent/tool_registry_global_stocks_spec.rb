# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::ToolRegistry do
  let(:read_policy) { DhanHQ::Agent::Policy.read_only }
  let(:write_policy) { DhanHQ::Agent::Policy.new(scopes: DhanHQ::Agent::Policy::ALL_SCOPES) }

  before do
    DhanHQ.configure do |config|
      config.client_id = "1000000001"
      config.access_token = "test-token"
    end
    described_class.instance_variable_set(:@tools, nil)
  end

  after do
    DhanHQ.reset_configuration!
    described_class.instance_variable_set(:@tools, nil)
  end

  describe "registration" do
    it "registers the Global Stocks tools" do
      expect(described_class.tools.keys).to include(
        "dhan_global_holdings", "dhan_global_funds", "dhan_global_orders",
        "dhan_global_trades", "dhan_global_market_status", "dhan_global_order_estimate",
        "dhan_global_place_order", "dhan_global_cancel_order"
      )
    end

    it "registers the basket order tool" do
      expect(described_class.tools.keys).to include("dhan_multi_order")
    end

    it "scopes the read tools as read_only" do
      expect(described_class.tools["dhan_global_holdings"].risk).to eq("read_only")
      expect(described_class.tools["dhan_global_holdings"].scope).to eq("portfolio:read")
    end

    it "scopes order placement as a live write" do
      tool = described_class.tools["dhan_global_place_order"]

      expect(tool.risk).to eq("live_write")
      expect(tool.scope).to eq("orders:write")
    end

    it "advertises the AMOUNT order type in the input schema" do
      properties = described_class.tools["dhan_global_place_order"].schema[:properties]

      expect(properties[:order_type][:enum]).to include("AMOUNT")
      expect(properties[:amount]).to be_a(Hash)
    end

    it "does not require an exchange segment for US orders" do
      expect(described_class.tools["dhan_global_place_order"].schema[:required])
        .to eq(%w[transaction_type order_type security_id])
    end

    it "caps the basket schema at the API limit" do
      orders = described_class.tools["dhan_multi_order"].schema[:properties][:orders]

      expect(orders[:maxItems]).to eq(DhanHQ::Contracts::MultiOrderContract::MAX_ORDERS)
    end
  end

  describe "policy enforcement" do
    it "allows a read tool under the read-only policy" do
      allow(DhanHQ::Models::GlobalStocks::Holding).to receive(:all).and_return([])

      expect { described_class.execute("dhan_global_holdings", {}, policy: read_policy) }.not_to raise_error
    end

    it "blocks order placement under the read-only policy" do
      expect { described_class.execute("dhan_global_place_order", {}, policy: read_policy) }
        .to raise_error(DhanHQ::Error, /Agent scope required/)
    end

    it "blocks order placement when writes are not enabled in the environment" do
      stub_const("ENV", ENV.to_h.merge("DHANHQ_MCP_ENABLE_WRITES" => nil, "LIVE_TRADING" => nil))

      expect { described_class.execute("dhan_global_place_order", {}, policy: write_policy) }
        .to raise_error(DhanHQ::LiveTradingDisabledError)
    end

    it "blocks the basket tool under the read-only policy" do
      expect { described_class.execute("dhan_multi_order", { orders: [] }, policy: read_policy) }
        .to raise_error(DhanHQ::Error, /Agent scope required/)
    end
  end

  describe "handlers" do
    it "reports US market status with a boolean open flag" do
      status = DhanHQ::Models::GlobalStocks::MarketStatus.new(
        { status: "open", holidayFlag: false }, skip_validation: true
      )
      allow(DhanHQ::Models::GlobalStocks::MarketStatus).to receive(:fetch).and_return(status)

      result = described_class.execute("dhan_global_market_status", {}, policy: read_policy)

      expect(result[:open]).to be(true)
      expect(result[:status]).to eq("open")
    end

    it "combines charges and margin in the estimate tool" do
      allow(DhanHQ::Models::GlobalStocks::OrderEstimate).to receive(:calculate)
        .and_return(DhanHQ::Models::GlobalStocks::OrderEstimate.new({ brokerage: 1.5 }, skip_validation: true))
      allow(DhanHQ::Models::GlobalStocks::Margin).to receive(:calculate)
        .and_return(DhanHQ::Models::GlobalStocks::Margin.new(
                      { totalMargin: 360.0, availableBal: 1000.0, insufficientBal: 0.0 }, skip_validation: true
                    ))

      result = described_class.execute(
        "dhan_global_order_estimate",
        { security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 2.0 },
        policy: read_policy
      )

      expect(result[:total_charges]).to eq(1.5)
      expect(result[:total_margin]).to eq(360.0)
      expect(result[:sufficient]).to be(true)
    end
  end
end
