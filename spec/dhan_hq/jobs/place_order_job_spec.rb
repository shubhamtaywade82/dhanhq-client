# frozen_string_literal: true

require "active_job"

RSpec.describe DhanHQ::Jobs::PlaceOrderJob do
  let(:params) do
    {
      transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "INTRADAY",
      order_type: "LIMIT", validity: "DAY", security_id: "11536", quantity: 5, price: 1500.0
    }
  end

  describe "#perform" do
    it "places the order via the bang variant" do
      order = instance_double(DhanHQ::Models::Order)
      allow(DhanHQ::Models::Order).to receive(:place!).with(params).and_return(order)

      described_class.perform_now(params)

      expect(DhanHQ::Models::Order).to have_received(:place!).with(params)
    end

    # discard_on is handled inside ActiveJob's own execute, before an exception
    # would ever reach a queue adapter's (Sidekiq's, chief among them) own
    # backend-level retry. Proving the exception never escapes perform_now is
    # exactly what proves no adapter -- whichever one a consuming app uses --
    # gets a chance to retry this non-idempotent write.
    it "discards on OrderError rather than letting it raise out of perform_now" do
      allow(DhanHQ::Models::Order).to receive(:place!).and_raise(DhanHQ::OrderError, "rejected")

      expect { described_class.perform_now(params) }.not_to raise_error
    end

    it "discards on RiskViolation rather than letting it raise out of perform_now" do
      allow(DhanHQ::Models::Order).to receive(:place!).and_raise(DhanHQ::RiskViolation, "blocked")

      expect { described_class.perform_now(params) }.not_to raise_error
    end

    it "logs a rejected order instead of silently swallowing it" do
      allow(DhanHQ::Models::Order).to receive(:place!).and_raise(DhanHQ::OrderError, "rejected")
      allow(DhanHQ.logger).to receive(:error)

      described_class.perform_now(params)

      expect(DhanHQ.logger).to have_received(:error).with(/order rejected: rejected/)
    end

    it "logs a risk-blocked order instead of silently swallowing it" do
      allow(DhanHQ::Models::Order).to receive(:place!).and_raise(DhanHQ::RiskViolation, "blocked")
      allow(DhanHQ.logger).to receive(:warn)

      described_class.perform_now(params)

      expect(DhanHQ.logger).to have_received(:warn).with(/risk check blocked the order: blocked/)
    end
  end
end
