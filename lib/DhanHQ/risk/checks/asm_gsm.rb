# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Blocks trading on ASM/GSM restricted instruments.
      class AsmGsm
        def self.run!(instrument:, **_unused)
          return unless instrument.asm_gsm_flag == "Y"

          raise DhanHQ::RiskViolation,
                "ASM/GSM restricted instrument (#{instrument.asm_gsm_category})"
        end
      end
    end
  end
end
