# frozen_string_literal: true

module DhanHQ
  module Analysis
    # Provides helpers for selecting option moneyness based on indicators.
    module MoneynessHelper
      module_function

      def pick_moneyness(indicators:, min_adx:, strong_adx:, bias: nil)
        # Mark bias as intentionally observed for future rules
        bias&.to_sym

        m60 = indicators[:m60] || {}
        adx = m60[:adx].to_f
        rsi = m60[:rsi].to_f

        return :atm if adx < min_adx
        return :otm if adx >= strong_adx && rsi >= 60

        :atm
      end
    end
  end
end
