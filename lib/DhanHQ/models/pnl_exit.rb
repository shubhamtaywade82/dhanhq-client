# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model for managing P&L-based automatic position exit.
    #
    # The P&L Based Exit API allows users to configure automatic exit rules based on
    # cumulative profit or loss thresholds. When the defined limits are breached, all
    # applicable positions are exited automatically.
    #
    # @note The configured P&L based exit remains active for the current day and is
    #   reset at the end of the trading session.
    #
    # @example Configure P&L-based exit
    #   response = DhanHQ::Models::PnlExit.configure(
    #     profit_value: 1500.0,
    #     loss_value: 500.0,
    #     product_type: ["INTRADAY", "DELIVERY"],
    #     enable_kill_switch: true
    #   )
    #   puts response[:pnl_exit_status] # => "ACTIVE"
    #
    # @example Check current P&L exit configuration
    #   config = DhanHQ::Models::PnlExit.status
    #   puts "Status: #{config.pnl_exit_status}"
    #   puts "Profit threshold: ₹#{config.profit}"
    #   puts "Loss threshold: ₹#{config.loss}"
    #
    # @example Stop P&L-based exit
    #   response = DhanHQ::Models::PnlExit.stop
    #   puts response[:pnl_exit_status] # => "DISABLED"
    #
    class PnlExit < BaseModel
      HTTP_PATH = "/v2/pnlExit"

      attributes :pnl_exit_status, :profit, :loss, :segments, :enable_kill_switch

      class << self
        ##
        # Provides a shared instance of the PnlExit resource.
        #
        # @return [DhanHQ::Resources::PnlExit] The PnlExit resource client instance
        def resource
          @resource ||= DhanHQ::Resources::PnlExit.new
        end

        ##
        # Configure automatic P&L-based position exit.
        #
        # When the defined profit or loss thresholds are breached during the trading day,
        # all applicable positions are exited automatically.
        #
        # @param profit_value [Float] Profit threshold that triggers exit (e.g., 1500.0)
        # @param loss_value [Float] Loss threshold that triggers exit (e.g., 500.0)
        # @param product_type [Array<String>] Product types to apply. e.g., ["INTRADAY", "DELIVERY"]
        # @param enable_kill_switch [Boolean] Whether to activate kill switch after exit
        #
        # @return [Hash{Symbol => String}] Response hash containing:
        #   - **:pnl_exit_status** [String] "ACTIVE" on success
        #   - **:message** [String] Confirmation message
        #
        # @example Configure with kill switch
        #   DhanHQ::Models::PnlExit.configure(
        #     profit_value: 2000.0,
        #     loss_value: 1000.0,
        #     product_type: ["INTRADAY"],
        #     enable_kill_switch: true
        #   )
        #
        def configure(profit_value:, loss_value:, product_type:, enable_kill_switch: false)
          params = {
            profitValue: profit_value.to_s,
            lossValue: loss_value.to_s,
            productType: product_type,
            enableKillSwitch: enable_kill_switch
          }
          resource.configure(params)
        end

        ##
        # Stop/disable the active P&L-based exit configuration.
        #
        # @return [Hash{Symbol => String}] Response hash containing:
        #   - **:pnl_exit_status** [String] "DISABLED"
        #   - **:message** [String] Confirmation message
        #
        # @example Disable P&L exit
        #   response = DhanHQ::Models::PnlExit.stop
        #   puts response[:pnl_exit_status] # => "DISABLED"
        #
        def stop
          resource.stop
        end

        ##
        # Fetch the currently active P&L-based exit configuration.
        #
        # @return [PnlExit] PnlExit object with current configuration.
        #   - **:pnl_exit_status** [String] "ACTIVE" or "DISABLED"
        #   - **:profit** [String] Configured profit threshold
        #   - **:loss** [String] Configured loss threshold
        #   - **:segments** [Array<String>] Active product types
        #   - **:enable_kill_switch** [Boolean] Whether kill switch is enabled
        #
        # @example Check configuration
        #   config = DhanHQ::Models::PnlExit.status
        #   if config.pnl_exit_status == "ACTIVE"
        #     puts "P&L exit active: profit=₹#{config.profit}, loss=₹#{config.loss}"
        #   end
        #
        def status
          response = resource.status
          return nil unless response.is_a?(Hash)

          new(response, skip_validation: true)
        end
      end

      ##
      # No validation contract needed — server-side validation handles it.
      #
      # @return [nil]
      # @api private
      def validation_contract
        nil
      end
    end
  end
end
