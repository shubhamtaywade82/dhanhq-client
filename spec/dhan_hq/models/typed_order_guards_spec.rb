# frozen_string_literal: true

require "spec_helper"

# Locks in the typed-error contract for order models whose id guards were
# converted from bare RuntimeError to DhanHQ::OrderError (PR review follow-up
# to the gem-audit pass, which had only converted Models::Order).
# rubocop:disable RSpec/DescribeClass -- one describe per derivative model, below
RSpec.describe "typed order guards on derivative order models" do
  %w[TwapOrder IcebergOrder].each do |model_name|
    describe DhanHQ::Models.const_get(model_name) do
      it "raises DhanHQ::OrderError from #modify when order id is missing" do
        record = described_class.new({}, skip_validation: true)
        noun = described_class.name.split("::").last.gsub(/Order$/, "").downcase

        expect { record.modify({}) }
          .to raise_error(DhanHQ::OrderError, /Order ID is required to modify an? #{noun} order/i)
      end

      it "raises DhanHQ::OrderError from #cancel when order id is missing" do
        record = described_class.new({}, skip_validation: true)
        noun = described_class.name.split("::").last.gsub(/Order$/, "").downcase

        expect { record.cancel }
          .to raise_error(DhanHQ::OrderError, /Order ID is required to cancel an? #{noun} order/i)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
