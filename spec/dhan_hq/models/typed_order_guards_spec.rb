# frozen_string_literal: true

require "spec_helper"

# Locks in the typed-error contract for order models whose id guards were
# converted from bare RuntimeError to DhanHQ::OrderError (PR review follow-up
# to the gem-audit pass, which had only converted Models::Order).
RSpec.describe "typed order guards on derivative order models" do
  %w[TwapOrder IcebergOrder].each do |model_name|
    model = DhanHQ::Models.const_get(model_name)
    noun = model_name.gsub(/Order$/, "").downcase

    describe model do
      it "raises DhanHQ::OrderError from #modify when order id is missing" do
        record = model.new({}, skip_validation: true)

        expect { record.modify({}) }
          .to raise_error(DhanHQ::OrderError, /Order ID is required to modify an? #{noun} order/i)
      end

      it "raises DhanHQ::OrderError from #cancel when order id is missing" do
        record = model.new({}, skip_validation: true)

        expect { record.cancel }
          .to raise_error(DhanHQ::OrderError, /Order ID is required to cancel an? #{noun} order/i)
      end
    end
  end
end
