# frozen_string_literal: true

RSpec.describe DhanHQ::WriteResult do
  let(:error_object) { DhanHQ::ErrorObject.new({ errorMessage: "rejected by exchange" }) }
  let(:model) { DhanHQ::Models::Order.new({ orderId: "1" }, skip_validation: true) }

  describe ".failure?" do
    it "treats every shape the models currently use for failure as a failure" do
      expect(described_class.failure?(nil)).to be(true)
      expect(described_class.failure?(false)).to be(true)
      expect(described_class.failure?(error_object)).to be(true)
    end

    it "treats a model and a truthy value as success" do
      expect(described_class.failure?(model)).to be(false)
      expect(described_class.failure?(true)).to be(false)
    end

    it "does not treat an empty collection as failure" do
      expect(described_class.failure?([])).to be(false)
      expect(described_class.failure?({})).to be(false)
    end
  end

  describe ".success?" do
    it "is the inverse of .failure?" do
      [nil, false, error_object, model, true, []].each do |value|
        expect(described_class.success?(value)).to be(!described_class.failure?(value))
      end
    end
  end

  describe ".unwrap!" do
    it "returns the result untouched on success" do
      expect(described_class.unwrap!(model, operation: "X.place")).to be(model)
    end

    it "raises OrderError by default" do
      expect { described_class.unwrap!(nil, operation: "X.place") }
        .to raise_error(DhanHQ::OrderError, /X\.place failed/)
    end

    it "raises something an existing rescue DhanHQ::Error handler still catches" do
      expect { described_class.unwrap!(nil, operation: "X.place") }.to raise_error(DhanHQ::Error)
    end

    it "carries the diagnostics an ErrorObject held" do
      expect { described_class.unwrap!(error_object, operation: "X.place") }
        .to raise_error(DhanHQ::OrderError, /rejected by exchange/)
    end

    it "falls back to supplied validation errors when the result carries none" do
      expect { described_class.unwrap!(false, operation: "X.save", errors: { quantity: ["is missing"] }) }
        .to raise_error(DhanHQ::OrderError, /quantity/)
    end

    it "distinguishes nil from false rather than inventing a cause" do
      expect { described_class.unwrap!(nil, operation: "X.place") }
        .to raise_error(/returned no record/)
      expect { described_class.unwrap!(false, operation: "X.cancel") }
        .to raise_error(/rejected the request/)
    end

    it "honours a caller-supplied error class" do
      expect { described_class.unwrap!(nil, operation: "X.save", error_class: DhanHQ::ValidationError) }
        .to raise_error(DhanHQ::ValidationError)
    end

    it "ignores an empty errors hash" do
      expect { described_class.unwrap!(false, operation: "X.cancel", errors: {}) }
        .to raise_error(/rejected the request/)
    end
  end

  describe ".operation_label" do
    it "uses dot notation for a class" do
      expect(described_class.operation_label(DhanHQ::Models::Order, :place))
        .to eq("DhanHQ::Models::Order.place")
    end

    it "uses hash notation for an instance" do
      expect(described_class.operation_label(model, :cancel))
        .to eq("DhanHQ::Models::Order#cancel")
    end
  end

  describe ".errors_from" do
    it "is nil for a class" do
      expect(described_class.errors_from(DhanHQ::Models::Order)).to be_nil
    end

    it "reads the errors hash off a model" do
      expect(described_class.errors_from(model)).to eq({})
    end
  end
end
