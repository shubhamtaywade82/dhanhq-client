# frozen_string_literal: true

module DhanHQ
  module WS
    module MarketDepth
      ##
      # Decoder for Market Depth WebSocket messages
      # Handles parsing of market depth data (bid/ask levels)
      class Decoder
        ##
        # Decode raw WebSocket message to market depth data
        # @param data [String] Raw WebSocket message
        # @return [Hash, nil] Parsed market depth data or nil if invalid
        def decode(data)
          return nil if data.nil? || data.empty?

          begin
            # Parse JSON message
            message = JSON.parse(data)

            # Handle different message types
            case message["Type"]
            when "depth_update"
              parse_depth_update(message["Data"])
            when "depth_snapshot"
              parse_depth_snapshot(message["Data"])
            else
              # Unknown message type
              nil
            end
          rescue JSON::ParserError => e
            DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth::Decoder] JSON parse error: #{e.message}")
            nil
          rescue StandardError => e
            DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth::Decoder] Decode error: #{e.class} #{e.message}")
            nil
          end
        end

        private

        ##
        # Parse depth update message
        # @param data [Hash] Message data
        # @return [Hash] Parsed depth update
        def parse_depth_update(data)
          {
            type: :depth_update,
            symbol: data["Symbol"],
            exchange_segment: data["ExchangeSegment"],
            security_id: data["SecurityId"],
            timestamp: data["Timestamp"],
            bids: parse_bid_levels(data["Bids"]),
            asks: parse_ask_levels(data["Asks"]),
            best_bid: data["BestBid"],
            best_ask: data["BestAsk"],
            spread: calculate_spread(data["BestBid"], data["BestAsk"]),
            total_bid_qty: data["TotalBidQty"],
            total_ask_qty: data["TotalAskQty"]
          }
        end

        ##
        # Parse depth snapshot message
        # @param data [Hash] Message data
        # @return [Hash] Parsed depth snapshot
        def parse_depth_snapshot(data)
          {
            type: :depth_snapshot,
            symbol: data["Symbol"],
            exchange_segment: data["ExchangeSegment"],
            security_id: data["SecurityId"],
            timestamp: data["Timestamp"],
            bids: parse_bid_levels(data["Bids"]),
            asks: parse_ask_levels(data["Asks"]),
            best_bid: data["BestBid"],
            best_ask: data["BestAsk"],
            spread: calculate_spread(data["BestBid"], data["BestAsk"]),
            total_bid_qty: data["TotalBidQty"],
            total_ask_qty: data["TotalAskQty"]
          }
        end

        ##
        # Parse bid levels
        # @param bids [Array] Raw bid levels
        # @return [Array<Hash>] Parsed bid levels
        def parse_bid_levels(bids)
          return [] unless bids.is_a?(Array)

          bids.map do |bid|
            {
              price: bid["Price"].to_f,
              quantity: bid["Quantity"].to_i,
              orders: bid["Orders"] || 1
            }
          end
        end

        ##
        # Parse ask levels
        # @param asks [Array] Raw ask levels
        # @return [Array<Hash>] Parsed ask levels
        def parse_ask_levels(asks)
          return [] unless asks.is_a?(Array)

          asks.map do |ask|
            {
              price: ask["Price"].to_f,
              quantity: ask["Quantity"].to_i,
              orders: ask["Orders"] || 1
            }
          end
        end

        ##
        # Calculate spread between best bid and ask
        # @param best_bid [Float, String] Best bid price
        # @param best_ask [Float, String] Best ask price
        # @return [Float] Spread amount
        def calculate_spread(best_bid, best_ask)
          bid = best_bid.to_f
          ask = best_ask.to_f
          return 0.0 if bid.zero? || ask.zero?

          ask - bid
        end
      end
    end
  end
end
