# frozen_string_literal: true

module DhanHQ
  module AI
    # Helper methods for generating prompts for AI trading assistants.
    #
    # Provides methods to create system prompts, user prompts,
    # and context summaries for AI models.
    module PromptHelpers
      # Generate a system prompt for an AI trading assistant.
      #
      # @param capabilities [Array<String>] List of capabilities
      # @return [String] System prompt
      def self.system_prompt(capabilities: [])
        <<~PROMPT.strip
          You are an AI trading assistant for Indian stock markets (NSE, BSE, MCX).

          Your capabilities:
          - Fetch market data (LTP, OHLC, quotes)
          - Place, modify, and cancel orders
          - View portfolio holdings, positions, and orders
          - Calculate option Greeks and implied volatility
          - Analyze option chains and Max Pain
          - Apply risk management rules

          #{"Additional capabilities:\n#{capabilities.map { |c| "- #{c}" }.join("\n")}" unless capabilities.empty?}

          Rules:
          - Always confirm before placing live orders
          - Use correlation_id for all agent-originated orders
          - Never expose access tokens or secrets
          - Prefer read-only operations unless explicitly asked to trade
          - Validate instruments before trading using search
        PROMPT
      end

      # Generate a portfolio summary prompt.
      #
      # @param holdings [Array<DhanHQ::Models::Holding>] Holdings data
      # @param positions [Array<DhanHQ::Models::Position>] Positions data
      # @param funds [DhanHQ::Models::Funds] Funds data
      # @return [String] Portfolio summary
      def self.portfolio_summary(holdings:, positions:, funds:)
        lines = ["=== Portfolio Summary ==="]
        lines << "Funds: #{funds.to_prompt}" if funds
        lines << ""
        lines << "Holdings (#{holdings.size}):"
        holdings.each { |h| lines << "  #{h.to_prompt}" }
        lines << ""
        lines << "Open Positions (#{positions.count(&:open?)}):"
        positions.select(&:open?).each { |p| lines << "  #{p.to_prompt}" }
        lines.join("\n")
      end

      # Generate a market analysis prompt.
      #
      # @param snapshot [DhanHQ::MarketData::MarketSnapshot] Market snapshot
      # @param series [DhanHQ::MarketData::OHLCSeries] OHLC series
      # @return [String] Market analysis prompt
      def self.market_analysis(snapshot:, series: nil)
        lines = ["=== Market Analysis ==="]
        lines << "Snapshot: #{snapshot.size} instruments"
        lines << "Series: #{series&.size || 0} candles"

        if series&.any?
          lines << "Latest close: ₹#{series.last.close}"
          lines << "Average close: ₹#{series.average_close&.round(2)}"
          lines << "Price range: ₹#{series.price_range&.round(2)}"
        end

        lines.join("\n")
      end

      # Generate an order confirmation prompt.
      #
      # @param order_params [Hash] Order parameters
      # @return [String] Order confirmation prompt
      def self.order_confirmation(order_params)
        <<~PROMPT.strip
          === Order Confirmation Required ===
          #{order_params[:transaction_type]} #{order_params[:quantity]}x #{order_params[:security_id]}
          Exchange: #{order_params[:exchange_segment]}
          Product: #{order_params[:product_type]}
          Type: #{order_params[:order_type]}
          #{order_params[:price] ? "Price: ₹#{order_params[:price]}" : "Market Price"}
          #{"Trigger: ₹#{order_params[:trigger_price]}" if order_params[:trigger_price]}

          Please confirm this order.
        PROMPT
      end

      # Generate a risk report prompt.
      #
      # @param positions [Array<DhanHQ::Models::Position>] Current positions
      # @param risk_params [Hash] Risk parameters
      # @return [String] Risk report
      def self.risk_report(positions:, risk_params: {})
        lines = ["=== Risk Report ==="]
        total_unrealized = positions.sum { |p| p.unrealized_profit.to_f }
        total_realized = positions.sum { |p| p.realized_profit.to_f }

        lines << "Total Unrealized P&L: ₹#{total_unrealized.round(2)}"
        lines << "Total Realized P&L: ₹#{total_realized.round(2)}"
        lines << "Open Positions: #{positions.count(&:open?)}"

        lines << "Max Drawdown: #{risk_params[:max_drawdown]}%" if risk_params[:max_drawdown]

        lines << "Daily Loss Limit: ₹#{risk_params[:daily_loss_limit]}" if risk_params[:daily_loss_limit]

        lines.join("\n")
      end
    end
  end
end
