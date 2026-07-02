# frozen_string_literal: true

module DhanHQ
  # AI integration layer for building AI-powered trading assistants.
  #
  # Provides workflow orchestration, prompt helpers, and context
  # serialization for AI agents.
  #
  # @example Build context for AI
  #   context = DhanHQ::AI::ContextBuilder.build do |ctx|
  #     ctx.add_portfolio
  #     ctx.add_positions
  #     ctx.add_recent_orders(limit: 10)
  #     ctx.add_market_snapshot(security_ids: ["2885"])
  #   end
  #
  module AI
    # Build context for AI agents from current account state.
    #
    # Provides methods to serialize portfolio, positions, orders,
    # and market data into prompt-friendly formats.
    class ContextBuilder
      attr_reader :sections

      def initialize
        @sections = []
      end

      # Build context using a block.
      #
      # @yield [builder] The context builder
      # @return [DhanHQ::AI::ContextBuilder]
      def self.build
        builder = new
        yield builder
        builder
      end

      # Add portfolio holdings to context.
      def add_portfolio
        holdings = DhanHQ::Models::Holding.all
        @sections << {
          type: :portfolio,
          data: holdings.map(&:to_prompt),
          summary: "Portfolio: #{holdings.size} holdings"
        }
        self
      end

      # Add current positions to context.
      def add_positions
        positions = DhanHQ::Models::Position.all
        active = positions.select(&:open?)
        @sections << {
          type: :positions,
          data: active.map(&:to_prompt),
          summary: "Positions: #{active.size} open"
        }
        self
      end

      # Add recent orders to context.
      #
      # @param limit [Integer] Number of recent orders (default: 10)
      def add_recent_orders(limit: 10)
        orders = DhanHQ::Models::Order.all
        recent = orders.last(limit)
        @sections << {
          type: :orders,
          data: recent.map(&:to_prompt),
          summary: "Orders: #{orders.size} total, #{recent.size} recent"
        }
        self
      end

      # Add fund information to context.
      def add_funds
        funds = DhanHQ::Models::Funds.fetch
        @sections << {
          type: :funds,
          data: [funds.to_prompt],
          summary: "Funds: Available ₹#{funds.available_balance}"
        }
        self
      end

      # Add market snapshot to context.
      #
      # @param security_ids [Array<String>] Security IDs to fetch
      def add_market_snapshot(security_ids:)
        instruments = security_ids.each_with_object({}) do |sec_id, hash|
          hash[DhanHQ::Constants::ExchangeSegment::NSE_EQ] ||= []
          hash[DhanHQ::Constants::ExchangeSegment::NSE_EQ] << sec_id
        end

        response = DhanHQ::Models::MarketFeed.ltp(instruments)
        snapshot = DhanHQ::MarketData::MarketSnapshot.from_response(response)

        @sections << {
          type: :market_data,
          data: [snapshot.empty? ? "No data" : "Snapshot with #{snapshot.size} instruments"],
          summary: "Market: #{snapshot.size} instruments"
        }
        self
      end

      # Add custom section to context.
      #
      # @param type [Symbol] Section type
      # @param data [Array<String>] Prompt strings
      # @param summary [String] Section summary
      def add_section(type:, data:, summary:)
        @sections << { type: type, data: data, summary: summary }
        self
      end

      # Serialize context to a prompt string.
      #
      # @return [String] Formatted context string
      def to_prompt
        lines = ["=== DhanHQ Trading Context ==="]
        lines << "Generated at: #{Time.now}"
        lines << ""

        @sections.each do |section|
          lines << "--- #{section[:summary]} ---"
          section[:data].each { |item| lines << "  #{item}" }
          lines << ""
        end

        lines.join("\n")
      end

      # Serialize context to a hash.
      #
      # @return [Hash] Context as hash
      def to_h
        {
          generated_at: Time.now,
          sections: @sections
        }
      end
    end
  end
end
