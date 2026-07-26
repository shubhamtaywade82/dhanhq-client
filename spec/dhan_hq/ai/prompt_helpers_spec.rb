# frozen_string_literal: true

RSpec.describe DhanHQ::AI::PromptHelpers do
  # Real models rather than doubles: attribute readers are defined per-instance by
  # BaseModel#assign_attributes, so instance_double cannot verify them, and an
  # unverified double would not catch a renamed attribute.
  def position(open:, unrealized: 0.0, realized: 0.0, symbol: "NIFTY")
    DhanHQ::Models::Position.new(
      { positionType: open ? "LONG" : "CLOSED", netQty: open ? 50 : 0,
        tradingSymbol: symbol, securityId: "11536", exchangeSegment: "NSE_FNO",
        productType: "INTRADAY", unrealizedProfit: unrealized, realizedProfit: realized },
      skip_validation: true
    )
  end

  def holding(symbol: "RELIANCE", quantity: 10)
    DhanHQ::Models::Holding.new(
      { tradingSymbol: symbol, securityId: "2885", exchange: "NSE", totalQty: quantity },
      skip_validation: true
    )
  end

  describe ".portfolio_summary" do
    let(:funds) { instance_double(DhanHQ::Models::Funds, to_prompt: "available=₹50000") }

    it "reports funds, holdings and open positions" do
      summary = described_class.portfolio_summary(
        holdings: [holding(symbol: "RELIANCE", quantity: 10)],
        positions: [position(open: true, symbol: "NIFTY")],
        funds: funds
      )

      expect(summary).to include("=== Portfolio Summary ===", "available=₹50000",
                                 "Holdings (1):", "10x RELIANCE",
                                 "Open Positions (1):", "LONG 50x NIFTY")
    end

    it "counts and lists only open positions" do
      summary = described_class.portfolio_summary(
        holdings: [],
        positions: [position(open: true, symbol: "OPENONE"), position(open: false, symbol: "CLOSEDONE")],
        funds: nil
      )

      expect(summary).to include("Open Positions (1):", "OPENONE")
      expect(summary).not_to include("CLOSEDONE")
    end

    it "omits the funds line when funds are unavailable" do
      summary = described_class.portfolio_summary(holdings: [], positions: [], funds: nil)

      expect(summary).not_to include("Funds:")
    end

    it "renders an empty portfolio rather than raising" do
      summary = described_class.portfolio_summary(holdings: [], positions: [], funds: nil)

      expect(summary).to include("Holdings (0):", "Open Positions (0):")
    end

    # `funds` was already guarded; the collections were not, so a nil slipped in from
    # a failed fetch used to raise NoMethodError from inside a prompt helper.
    it "treats nil collections as empty" do
      expect { described_class.portfolio_summary(holdings: nil, positions: nil, funds: nil) }
        .not_to raise_error
    end
  end

  describe ".risk_report" do
    it "sums P&L across every position, open or closed" do
      report = described_class.risk_report(
        positions: [position(open: true, unrealized: 100.5, realized: 10.0),
                    position(open: false, unrealized: -50.25, realized: 5.0)]
      )

      expect(report).to include("Total Unrealized P&L: ₹50.25")
      expect(report).to include("Total Realized P&L: ₹15.0")
    end

    it "counts only the open positions" do
      report = described_class.risk_report(
        positions: [position(open: true), position(open: false), position(open: true)]
      )

      expect(report).to include("Open Positions: 2")
    end

    it "includes risk parameters when supplied" do
      report = described_class.risk_report(
        positions: [],
        risk_params: { max_drawdown: 15, daily_loss_limit: 50_000 }
      )

      expect(report).to include("Max Drawdown: 15%", "Daily Loss Limit: ₹50000")
    end

    it "omits risk parameter lines when not supplied" do
      report = described_class.risk_report(positions: [])

      expect(report).not_to include("Max Drawdown", "Daily Loss Limit")
    end

    it "treats a nil position list as empty" do
      expect { described_class.risk_report(positions: nil) }.not_to raise_error
    end
  end

  describe ".order_confirmation" do
    let(:params) do
      { transaction_type: "BUY", quantity: 50, security_id: "11536",
        exchange_segment: "NSE_EQ", product_type: "INTRADAY", order_type: "LIMIT", price: 1500.0 }
    end

    it "renders the order for a human to confirm" do
      prompt = described_class.order_confirmation(params)

      expect(prompt).to include("BUY 50x 11536", "Exchange: NSE_EQ", "Price: ₹1500.0",
                                "Please confirm this order.")
    end

    it "says Market Price when no price is given" do
      prompt = described_class.order_confirmation(params.except(:price))

      expect(prompt).to include("Market Price")
    end

    it "includes the trigger price only for stop orders" do
      expect(described_class.order_confirmation(params.merge(trigger_price: 1490.0)))
        .to include("Trigger: ₹1490.0")
      expect(described_class.order_confirmation(params)).not_to include("Trigger:")
    end
  end
end
