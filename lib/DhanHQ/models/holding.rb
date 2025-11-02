# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model representing a single portfolio holding.
    #
    # Holdings represent all stocks/securities bought or sold in previous trading sessions.
    # This includes both T1 (pending delivery) and delivered quantities in your demat account.
    # Each holding provides information about quantities, average cost price, and availability
    # for transactions.
    #
    # @example Fetch all holdings
    #   holdings = DhanHQ::Models::Holding.all
    #   holdings.each do |holding|
    #     puts "#{holding.trading_symbol}: #{holding.total_qty} shares @ ₹#{holding.avg_cost_price}"
    #   end
    #
    # @example Find a specific holding by symbol
    #   holdings = DhanHQ::Models::Holding.all
    #   hdfc = holdings.find { |h| h.trading_symbol == "HDFC" }
    #   puts "Available quantity: #{hdfc.available_qty}" if hdfc
    #
    # @example Calculate portfolio value
    #   holdings = DhanHQ::Models::Holding.all
    #   total_value = holdings.sum { |h| h.total_qty * h.avg_cost_price }
    #   puts "Portfolio value: ₹#{total_value}"
    #
    class Holding < BaseModel
      # Base path used when retrieving holdings.
      HTTP_PATH = "/v2/holdings"

      attributes :exchange, :trading_symbol, :security_id, :isin, :total_qty,
                 :dp_qty, :t1_qty, :available_qty, :collateral_qty, :avg_cost_price

      class << self
        ##
        # Provides a shared instance of the Holdings resource.
        #
        # @return [DhanHQ::Resources::Holdings] The Holdings resource client instance
        def resource
          @resource ||= DhanHQ::Resources::Holdings.new
        end

        ##
        # Retrieves all holdings bought/sold in previous trading sessions.
        #
        # Fetches all T1 (pending delivery) and delivered quantities from your portfolio.
        # Includes information about available quantities for transaction, collateral quantities,
        # and average cost prices for each holding.
        #
        # @return [Array<Holding>] Array of Holding objects. Returns empty array if no holdings exist.
        #   Each Holding object contains (keys normalized to snake_case):
        #   - **:exchange** [String] Exchange identifier (e.g., "ALL", "NSE", "BSE")
        #   - **:trading_symbol** [String] Trading symbol of the security
        #   - **:security_id** [String] Exchange standard ID for each scrip
        #   - **:isin** [String] Universal standard ID for each scrip (International Securities Identification Number)
        #   - **:total_qty** [Integer] Total quantity of the holding
        #   - **:dp_qty** [Integer] Quantity delivered in demat account
        #   - **:t1_qty** [Integer] Quantity pending delivery in demat account (T+1 settlement)
        #   - **:available_qty** [Integer] Quantity available for transaction
        #   - **:collateral_qty** [Integer] Quantity placed as collateral with broker
        #   - **:avg_cost_price** [Float] Average buy price of total quantity
        #
        # @example Fetch all holdings
        #   holdings = DhanHQ::Models::Holding.all
        #   holdings.each do |holding|
        #     puts "#{holding.trading_symbol}: #{holding.total_qty} @ ₹#{holding.avg_cost_price}"
        #   end
        #
        # @example Filter holdings by available quantity
        #   holdings = DhanHQ::Models::Holding.all
        #   sellable = holdings.select { |h| h.available_qty > 0 }
        #   puts "You can sell #{sellable.size} holdings"
        #
        # @example Calculate total investment
        #   holdings = DhanHQ::Models::Holding.all
        #   total_investment = holdings.sum { |h| h.total_qty * h.avg_cost_price }
        #   puts "Total investment: ₹#{total_investment}"
        #
        # @note This is a GET request with no body parameters required
        # @note Returns empty array if no holdings exist or if {DhanHQ::NoHoldingsError} is raised
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |holding| new(holding, skip_validation: true) }
        rescue DhanHQ::NoHoldingsError
          []
        end
      end

      ##
      # Converts the Holding model attributes to a hash representation.
      #
      # Useful for serialization, logging, or passing holding data to other methods.
      #
      # @return [Hash{Symbol => String, Integer, Float}] Hash representation of the Holding model containing:
      #   - **:exchange** [String] Exchange identifier
      #   - **:trading_symbol** [String] Trading symbol
      #   - **:security_id** [String] Security ID
      #   - **:isin** [String] ISIN code
      #   - **:total_qty** [Integer] Total quantity
      #   - **:dp_qty** [Integer] Delivered quantity in demat
      #   - **:t1_qty** [Integer] T+1 pending delivery quantity
      #   - **:available_qty** [Integer] Available quantity for transaction
      #   - **:collateral_qty** [Integer] Quantity placed as collateral
      #   - **:avg_cost_price** [Float] Average cost price
      #
      # @example Convert holding to hash
      #   holding = DhanHQ::Models::Holding.all.first
      #   holding_hash = holding.to_h
      #   puts holding_hash[:trading_symbol]  # => "HDFC"
      #   puts holding_hash[:avg_cost_price]   # => 2655.0
      #
      def to_h
        {
          exchange: exchange,
          trading_symbol: trading_symbol,
          security_id: security_id,
          isin: isin,
          total_qty: total_qty,
          dp_qty: dp_qty,
          t1_qty: t1_qty,
          available_qty: available_qty,
          collateral_qty: collateral_qty,
          avg_cost_price: avg_cost_price
        }
      end
    end
  end
end
