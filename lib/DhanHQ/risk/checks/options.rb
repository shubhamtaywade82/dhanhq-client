# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces option-specific risk rules (index-only, stop loss, target, risk-reward).
      class Options
        def self.run!(args:, instrument:, **_unused)
          enforce_index!(instrument)
          enforce_stop_loss!(args)
          enforce_target!(args)
          enforce_risk_reward!(args)
        end

        def self.enforce_index!(instrument)
          return if instrument.instrument_type == "INDEX"

          raise DhanHQ::RiskViolation, "Options only allowed on index"
        end

        def self.enforce_stop_loss!(args)
          return if args["stop_loss"]

          raise DhanHQ::RiskViolation, "Stop loss required"
        end

        def self.enforce_target!(args)
          return if args["target"]

          raise DhanHQ::RiskViolation, "Target required"
        end

        def self.enforce_risk_reward!(args)
          stop_loss = args["stop_loss"].to_f
          target = args["target"].to_f
          return if target > stop_loss

          raise DhanHQ::RiskViolation, "Invalid risk-reward"
        end

        private_class_method :enforce_index!, :enforce_stop_loss!,
                             :enforce_target!, :enforce_risk_reward!
      end
    end
  end
end
