# frozen_string_literal: true

module DhanHQ
  module Agent
    # Callables that carry out each agent tool, one per tool.
    #
    # Every handler takes a hash of symbolized arguments and returns a model, a plain
    # hash, or a boolean. Policy enforcement happens before a handler is reached — see
    # {DhanHQ::Agent::ToolRegistry#execute} — so handlers here contain no scope or
    # live-trading checks of their own; the resources they call apply the
    # `LIVE_TRADING` gate and audit logging.
    module ToolHandlers
      module_function

      def profile_handler = ->(_) { DhanHQ::Models::Profile.fetch }

      def funds_handler = ->(_) { DhanHQ::Models::Funds.fetch }

      def holdings_handler = ->(_) { DhanHQ::Models::Holding.all }

      def positions_handler = ->(_) { DhanHQ::Models::Position.all }

      def orders_handler = ->(_) { DhanHQ::Models::Order.all }

      def trades_handler = ->(_) { DhanHQ::Models::Trade.today }

      def search_handler
        lambda do |arguments|
          query = arguments.fetch(:query)
          options = arguments.except(:query)
          DhanHQ::Models::Instrument.search(query, **options)
        end
      end

      def ltp_handler = ->(arguments) { DhanHQ::Models::MarketFeed.ltp(arguments[:instruments]) }

      def quote_handler = ->(arguments) { DhanHQ::Models::MarketFeed.quote(arguments[:instruments]) }

      def preview_handler = ->(arguments) { OrderPreview.new(arguments).to_h }

      def place_order_handler
        lambda do |arguments|
          instrument = DhanHQ::Models::Instrument.find_by_security_id(arguments[:exchange_segment], arguments[:security_id])
          unless instrument
            raise DhanHQ::RiskViolation,
                  "Cannot verify risk for unknown instrument: #{arguments[:exchange_segment]}:#{arguments[:security_id]}"
          end

          risk_type = instrument.instrument_type.to_s.start_with?("OPT") ? :options : :equity
          DhanHQ::Risk::Pipeline.run!(instrument: instrument, args: KeyCoercion.stringify(arguments), type: risk_type)

          DhanHQ::Models::Order.place(arguments)
        end
      end

      def cancel_order_handler
        lambda do |arguments|
          order = DhanHQ::Models::Order.find(arguments[:order_id])
          order&.cancel || false
        end
      end

      def global_holdings_handler = ->(_) { DhanHQ::Models::GlobalStocks::Holding.all }

      def global_funds_handler = ->(_) { DhanHQ::Models::GlobalStocks::Funds.fetch }

      def global_orders_handler = ->(_) { DhanHQ::Models::GlobalStocks::Order.all }

      def global_trades_handler = ->(_) { DhanHQ::Models::GlobalStocks::Trade.all }

      def global_market_status_handler
        lambda do |_|
          status = DhanHQ::Models::GlobalStocks::MarketStatus.fetch
          {
            status: status.status,
            open: status.open?,
            holiday: status.holiday?,
            market_open_time: status.market_open_time,
            market_close_time: status.market_close_time
          }
        end
      end

      # Combines the charge estimate and the margin requirement so an agent can decide
      # affordability in one call rather than two.
      def global_estimate_handler
        lambda do |arguments|
          estimate = DhanHQ::Models::GlobalStocks::OrderEstimate.calculate(arguments)
          margin = DhanHQ::Models::GlobalStocks::Margin.calculate(arguments)
          {
            total_charges: estimate.total_charges,
            brokerage: estimate.brokerage,
            total_margin: margin.total_margin,
            available_balance: margin.available_bal,
            sufficient: margin.sufficient?
          }
        end
      end

      # No {DhanHQ::Risk::Pipeline} run here: its checks resolve instruments from the
      # Indian scrip master and encode NSE/BSE rules, neither of which applies to US
      # equities. The LIVE_TRADING gate and audit logging in the resource still apply,
      # as does {Policy#require_write!}.
      def global_place_order_handler = ->(arguments) { DhanHQ::Models::GlobalStocks::Order.place(arguments) }

      def global_cancel_order_handler
        lambda do |arguments|
          order_id = arguments[:order_id]
          { order_id: order_id, cancelled: DhanHQ::Models::GlobalStocks::Order.cancel(order_id) }
        end
      end

      def multi_order_handler = ->(arguments) { DhanHQ::Models::MultiOrder.place(arguments[:orders]) }
    end
  end
end
