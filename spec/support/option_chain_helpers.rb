# frozen_string_literal: true

# Builds option chain fixtures matching the real DhanHQ::Models::OptionChain#fetch shape:
# { strikes: [{ strike:, call: { security_id:, last_price: }, put: { security_id:, last_price: } }] }
module OptionChainHelpers
  def build_option_chain(strikes)
    {
      strikes: strikes.map do |s|
        {
          strike: s[:strike].to_f,
          call: { security_id: s[:ce_id], last_price: s[:ce_price] },
          put: { security_id: s[:pe_id], last_price: s[:pe_price] }
        }
      end
    }
  end
end

RSpec.configure { |config| config.include OptionChainHelpers }
