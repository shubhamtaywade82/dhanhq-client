# frozen_string_literal: true

module DhanHQ
  # Risk management utilities for position sizing and order risk calculation.
  module Risk
    # Calculate optimal position size based on risk parameters.
    #
    # Supports multiple sizing methods:
    # - Fixed risk percentage of account
    # - Kelly criterion
    # - Volatility-based sizing
    #
    # @example Calculate position size with 2% risk
    #   size = DhanHQ::Risk::PositionSizer.calculate(
    #     account_balance: 100_000,
    #     risk_percent: 2.0,
    #     entry_price: 2500,
    #     stop_loss_price: 2450
    #   )
    #   #=> 40
    #
    class PositionSizer
      # Calculate position size based on fixed risk percentage.
      #
      # @param account_balance [Float] Total account balance
      # @param risk_percent [Float] Percentage of account to risk per trade (e.g., 2.0 for 2%)
      # @param entry_price [Float] Planned entry price
      # @param stop_loss_price [Float] Planned stop loss price
      # @param lot_size [Integer] Lot size for the instrument (default: 1)
      # @return [Integer] Number of shares/lots to trade
      def self.calculate(account_balance:, risk_percent:, entry_price:, stop_loss_price:, lot_size: 1)
        return 0 if account_balance <= 0 || entry_price <= 0 || stop_loss_price <= 0
        return 0 if entry_price == stop_loss_price

        risk_amount = account_balance * (risk_percent / 100.0)
        risk_per_share = (entry_price - stop_loss_price).abs

        return 0 if risk_per_share.zero?

        raw_shares = (risk_amount / risk_per_share).floor
        (raw_shares / lot_size).floor * lot_size
      end

      # Calculate position size using Kelly Criterion.
      #
      # @param win_rate [Float] Historical win rate (0.0 to 1.0)
      # @param avg_win [Float] Average winning trade amount
      # @param avg_loss [Float] Average losing trade amount (positive number)
      # @param account_balance [Float] Total account balance
      # @param entry_price [Float] Planned entry price
      # @param fraction [Float] Kelly fraction to use (default: 0.5 for half-Kelly)
      # @return [Integer] Number of shares to trade
      def self.kelly(win_rate:, avg_win:, avg_loss:, account_balance:, entry_price:, fraction: 0.5)
        return 0 if account_balance <= 0 || entry_price <= 0
        return 0 if avg_loss.zero? || win_rate <= 0 || win_rate >= 1

        # Kelly formula: f = (bp - q) / b
        # where b = avg_win/avg_loss, p = win_rate, q = 1 - win_rate
        b = avg_win / avg_loss
        kelly_fraction = ((b * win_rate) - (1 - win_rate)) / b

        return 0 if kelly_fraction <= 0

        # Apply fractional Kelly
        adjusted_fraction = kelly_fraction * fraction
        risk_amount = account_balance * adjusted_fraction
        shares = (risk_amount / entry_price).floor

        [shares, 0].max
      end

      # Calculate position size based on volatility (ATR-based).
      #
      # @param account_balance [Float] Total account balance
      # @param risk_percent [Float] Percentage of account to risk per trade
      # @param entry_price [Float] Planned entry price
      # @param atr [Float] Current ATR value
      # @param atr_multiplier [Float] Multiplier for ATR-based stop (default: 2.0)
      # @param lot_size [Integer] Lot size for the instrument (default: 1)
      # @return [Integer] Number of shares/lots to trade
      def self.volatility_based(account_balance:, risk_percent:, entry_price:, atr:, atr_multiplier: 2.0, lot_size: 1)
        return 0 if account_balance <= 0 || entry_price <= 0 || atr <= 0

        stop_distance = atr * atr_multiplier
        stop_loss_price = entry_price - stop_distance

        calculate(
          account_balance: account_balance,
          risk_percent: risk_percent,
          entry_price: entry_price,
          stop_loss_price: stop_loss_price,
          lot_size: lot_size
        )
      end
    end

    # Calculate stop loss and take profit levels.
    #
    # @example Calculate stop loss
    #   levels = DhanHQ::Risk::SLCalculator.stop_loss(
    #     entry_price: 2500,
    #     risk_percent: 2.0,
    #     atr: 50
    #   )
    #   #=> { fixed: 2450, atr_based: 2400 }
    #
    class SLCalculator
      # Calculate fixed percentage stop loss.
      #
      # @param entry_price [Float] Entry price
      # @param risk_percent [Float] Risk percentage (e.g., 2.0 for 2%)
      # @return [Float] Stop loss price
      def self.percentage(entry_price:, risk_percent:)
        return 0.0 if entry_price <= 0 || risk_percent <= 0

        entry_price * (1 - (risk_percent / 100.0))
      end

      # Calculate ATR-based stop loss.
      #
      # @param entry_price [Float] Entry price
      # @param atr [Float] Current ATR value
      # @param multiplier [Float] ATR multiplier (default: 2.0)
      # @return [Float] Stop loss price
      def self.atr_based(entry_price:, atr:, multiplier: 2.0)
        return 0.0 if entry_price <= 0 || atr <= 0

        entry_price - (atr * multiplier)
      end

      # Calculate support-based stop loss.
      #
      # @param entry_price [Float] Entry price
      # @param support_levels [Array<Float>] Array of support levels
      # @param buffer [Float] Buffer below support (default: 0.5%)
      # @return [Float] Stop loss price (below nearest support)
      def self.support_based(entry_price:, support_levels:, buffer: 0.005)
        return 0.0 if entry_price <= 0 || support_levels.nil? || support_levels.empty?

        # Find nearest support below entry price
        valid_supports = support_levels.select { |s| s < entry_price }
        return 0.0 if valid_supports.empty?

        nearest_support = valid_supports.max
        nearest_support * (1 - buffer)
      end

      # Calculate take profit based on risk-reward ratio.
      #
      # @param entry_price [Float] Entry price
      # @param stop_loss_price [Float] Stop loss price
      # @param risk_reward_ratio [Float] Desired risk:reward ratio (e.g., 2.0 for 1:2)
      # @return [Float] Take profit price
      def self.take_profit(entry_price:, stop_loss_price:, risk_reward_ratio: 2.0)
        return 0.0 if entry_price <= 0 || stop_loss_price <= 0

        risk = (entry_price - stop_loss_price).abs
        entry_price + (risk * risk_reward_ratio)
      end

      # Calculate trailing stop level.
      #
      # @param highest_price [Float] Highest price since entry
      # @param atr [Float] Current ATR value
      # @param multiplier [Float] ATR multiplier (default: 2.0)
      # @return [Float] Trailing stop price
      def self.trailing_stop(highest_price:, atr:, multiplier: 2.0)
        return 0.0 if highest_price <= 0 || atr <= 0

        highest_price - (atr * multiplier)
      end
    end

    # Manage trailing stop updates.
    #
    # @example Create trail manager
    #   trail = DhanHQ::Risk::TrailManager.new(
    #     entry_price: 2500,
    #     initial_stop: 2450,
    #     atr: 50,
    #     trail_multiplier: 2.0
    #   )
    #   trail.update(2600) #=> { stop: 2500, triggered: false }
    #
    class TrailManager
      attr_reader :entry_price, :initial_stop, :current_stop, :highest_price, :atr, :trail_multiplier

      def initialize(entry_price:, initial_stop:, atr:, trail_multiplier: 2.0)
        @entry_price = entry_price
        @initial_stop = initial_stop
        @current_stop = initial_stop
        @highest_price = entry_price
        @atr = atr
        @trail_multiplier = trail_multiplier
      end

      # Update trail with new price.
      #
      # @param current_price [Float] Current market price
      # @return [Hash] Hash with :stop, :highest, :triggered
      def update(current_price)
        return { stop: @current_stop, highest: @highest_price, triggered: false } if current_price <= 0

        # Update highest price
        @highest_price = current_price if current_price > @highest_price

        # Calculate new trailing stop
        new_stop = @highest_price - (@atr * @trail_multiplier)

        # Stop can only move up, never down
        @current_stop = new_stop if new_stop > @current_stop

        # Check if stop is triggered
        triggered = current_price <= @current_stop

        {
          stop: @current_stop,
          highest: @highest_price,
          triggered: triggered
        }
      end

      # Check if stop is triggered at current price.
      #
      # @param current_price [Float] Current market price
      # @return [Boolean]
      def triggered?(current_price)
        current_price <= @current_stop
      end

      # Calculate profit from entry to current price.
      #
      # @param current_price [Float] Current market price
      # @return [Float] Profit per share
      def profit(current_price)
        current_price - entry_price
      end

      # Calculate profit percentage from entry to current price.
      #
      # @param current_price [Float] Current market price
      # @return [Float] Profit percentage
      def profit_percent(current_price)
        return 0.0 if entry_price.zero?

        (profit(current_price) / entry_price * 100).round(2)
      end
    end
  end
end
