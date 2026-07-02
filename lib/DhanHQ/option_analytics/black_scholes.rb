# frozen_string_literal: true

module DhanHQ
  # Option analytics calculations for derivatives trading.
  module OptionAnalytics
    # Black-Scholes option pricing model for calculating theoretical option prices and Greeks.
    #
    # @example Calculate option price
    #   price = DhanHQ::OptionAnalytics::BlackScholes.price(
    #     spot: 24000,
    #     strike: 24200,
    #     time_to_expiry: 0.038, # ~10 days
    #     risk_free_rate: 0.065,
    #     volatility: 0.15,
    #     option_type: :call
    #   )
    #
    class BlackScholes
      # Calculate theoretical option price using Black-Scholes model.
      #
      # @param spot [Float] Current spot price
      # @param strike [Float] Strike price
      # @param time_to_expiry [Float] Time to expiry in years
      # @param risk_free_rate [Float] Risk-free interest rate (annualized)
      # @param volatility [Float] Implied volatility (annualized)
      # @param option_type [Symbol] :call or :put
      # @return [Float] Theoretical option price
      def self.price(spot:, strike:, time_to_expiry:, risk_free_rate:, volatility:, option_type:)
        return 0.0 if time_to_expiry <= 0

        d1 = calculate_d1(spot, strike, time_to_expiry, risk_free_rate, volatility)
        d2 = calculate_d2(d1, time_to_expiry, volatility)

        if option_type == :call
          (spot * normal_cdf(d1)) - (strike * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(d2))
        else
          (strike * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(-d2)) - (spot * normal_cdf(-d1))
        end
      end

      # Calculate option Greeks (Delta, Gamma, Theta, Vega, Rho).
      #
      # @param spot [Float] Current spot price
      # @param strike [Float] Strike price
      # @param time_to_expiry [Float] Time to expiry in years
      # @param risk_free_rate [Float] Risk-free interest rate (annualized)
      # @param volatility [Float] Implied volatility (annualized)
      # @param option_type [Symbol] :call or :put
      # @return [Hash] Hash with :delta, :gamma, :theta, :vega, :rho
      def self.greeks(spot:, strike:, time_to_expiry:, risk_free_rate:, volatility:, option_type:)
        return empty_greeks if time_to_expiry <= 0

        d1 = calculate_d1(spot, strike, time_to_expiry, risk_free_rate, volatility)
        d2 = calculate_d2(d1, time_to_expiry, volatility)

        gamma = normal_pdf(d1) / (spot * volatility * Math.sqrt(time_to_expiry))

        theta = if option_type == :call
                  calculate_call_theta(spot, strike, time_to_expiry, risk_free_rate, volatility, d1, d2)
                else
                  calculate_put_theta(spot, strike, time_to_expiry, risk_free_rate, volatility, d1, d2)
                end

        vega = spot * normal_pdf(d1) * Math.sqrt(time_to_expiry) / 100

        rho = if option_type == :call
                calculate_call_rho(spot, strike, time_to_expiry, risk_free_rate, d2)
              else
                calculate_put_rho(spot, strike, time_to_expiry, risk_free_rate, d2)
              end

        {
          delta: calculate_delta(spot, strike, time_to_expiry, risk_free_rate, volatility, option_type),
          gamma: gamma,
          theta: theta / 365.0, # Daily theta
          vega: vega,
          rho: rho / 100.0
        }
      end

      # Calculate implied volatility using Newton-Raphson method.
      #
      # @param market_price [Float] Observed market price of the option
      # @param spot [Float] Current spot price
      # @param strike [Float] Strike price
      # @param time_to_expiry [Float] Time to expiry in years
      # @param risk_free_rate [Float] Risk-free interest rate (annualized)
      # @param option_type [Symbol] :call or :put
      # @param tolerance [Float] Convergence tolerance (default: 0.0001)
      # @param max_iterations [Integer] Maximum iterations (default: 100)
      # @return [Float] Implied volatility
      # rubocop:disable Metrics/ParameterLists
      def self.implied_volatility(market_price:, spot:, strike:, time_to_expiry:, risk_free_rate:, option_type:,
                                  tolerance: 0.0001, max_iterations: 100)
        # rubocop:enable Metrics/ParameterLists
        return 0.0 if time_to_expiry <= 0 || market_price <= 0

        # Initial guess
        iv = 0.2
        max_iterations.times do
          theoretical_price = price(
            spot: spot, strike: strike, time_to_expiry: time_to_expiry,
            risk_free_rate: risk_free_rate, volatility: iv, option_type: option_type
          )

          diff = theoretical_price - market_price
          return iv if diff.abs < tolerance

          # Vega for Newton-Raphson
          vega = spot * normal_pdf(calculate_d1(spot, strike, time_to_expiry, risk_free_rate, iv)) *
                 Math.sqrt(time_to_expiry)

          return iv if vega < 1e-10

          iv -= diff / vega
          iv = [iv, 0.001].max # Prevent negative volatility
        end

        iv
      end

      class << self
        private

        def calculate_d1(spot, strike, time_to_expiry, risk_free_rate, volatility)
          (Math.log(spot / strike) + ((risk_free_rate + ((volatility**2) / 2)) * time_to_expiry)) /
            (volatility * Math.sqrt(time_to_expiry))
        end

        def calculate_d2(d1_val, time_to_expiry, volatility)
          d1_val - (volatility * Math.sqrt(time_to_expiry))
        end

        def calculate_delta(spot, strike, time_to_expiry, risk_free_rate, volatility, option_type)
          d1_val = calculate_d1(spot, strike, time_to_expiry, risk_free_rate, volatility)

          if option_type == :call
            normal_cdf(d1_val)
          else
            normal_cdf(d1_val) - 1
          end
        end

        def calculate_call_theta(spot, strike, time_to_expiry, risk_free_rate, volatility, d1_val, d2_val)
          term1 = -(spot * normal_pdf(d1_val) * volatility) / (2 * Math.sqrt(time_to_expiry))
          term2 = risk_free_rate * strike * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(d2_val)
          term1 - term2
        end

        def calculate_put_theta(spot, strike, time_to_expiry, risk_free_rate, volatility, d1_val, d2_val)
          term1 = -(spot * normal_pdf(d1_val) * volatility) / (2 * Math.sqrt(time_to_expiry))
          term2 = -risk_free_rate * strike * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(-d2_val)
          term1 - term2
        end

        def calculate_call_rho(_spot, strike, time_to_expiry, risk_free_rate, d2_val)
          strike * time_to_expiry * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(d2_val)
        end

        def calculate_put_rho(_spot, strike, time_to_expiry, risk_free_rate, d2_val)
          -strike * time_to_expiry * Math.exp(-risk_free_rate * time_to_expiry) * normal_cdf(-d2_val)
        end

        def empty_greeks
          { delta: 0.0, gamma: 0.0, theta: 0.0, vega: 0.0, rho: 0.0 }
        end

        # rubocop:disable Naming/MethodParameterName
        # Standard normal cumulative distribution function
        def normal_cdf(x)
          0.5 * (1 + erf(x / Math.sqrt(2)))
        end

        # Standard normal probability density function
        def normal_pdf(x)
          Math.exp(-0.5 * (x**2)) / Math.sqrt(2 * Math::PI)
        end

        # Error function approximation (Abramowitz and Stegun)
        def erf(x)
          sign = x.negative? ? -1 : 1
          x = x.abs

          t = 1.0 / (1.0 + (0.327_591_1 * x))
          y = 1.0 - (((((((((1.061_40_5429 * t) - 1.453_152_027) * t) + 1.421_413_741) * t) -
                      0.284_496_736) * t) + 0.254_829_592) * t * Math.exp(-x * x))

          sign * y
        end
        # rubocop:enable Naming/MethodParameterName
      end
    end
  end
end
