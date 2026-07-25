# frozen_string_literal: true

RSpec.describe DhanHQ::Concerns::BangWrites do
  # A stand-in for a model, so these examples describe the generated behaviour rather
  # than any one model's request plumbing.
  let(:writer_class) do
    Class.new do
      extend DhanHQ::Concerns::BangWrites

      class << self
        attr_accessor :class_result, :calls
      end

      def self.name
        "TestWriter"
      end

      def self.place(*args, **kwargs)
        self.calls = [args, kwargs]
        class_result
      end

      bang_class_writes :place

      attr_accessor :result, :errors

      def initialize
        @errors = {}
      end

      def cancel
        @result
      end

      bang_writes :cancel
    end
  end

  describe "generated class methods" do
    it "returns the underlying result on success" do
      writer_class.class_result = :placed

      expect(writer_class.place!).to be(:placed)
    end

    it "raises when the underlying method returns nil" do
      writer_class.class_result = nil

      expect { writer_class.place! }.to raise_error(DhanHQ::OrderError, /TestWriter\.place failed/)
    end

    it "raises when the underlying method returns an ErrorObject" do
      writer_class.class_result = DhanHQ::ErrorObject.new({ errorMessage: "nope" })

      expect { writer_class.place! }.to raise_error(DhanHQ::OrderError, /nope/)
    end

    it "forwards positional and keyword arguments through untouched" do
      writer_class.class_result = :placed

      writer_class.place!(1, 2, mode: :limit)

      expect(writer_class.calls).to eq([[1, 2], { mode: :limit }])
    end

    it "leaves the non-bang method's contract alone" do
      writer_class.class_result = nil

      expect(writer_class.place).to be_nil
    end
  end

  describe "generated instance methods" do
    subject(:writer) { writer_class.new }

    it "returns the underlying result on success" do
      writer.result = true

      expect(writer.cancel!).to be(true)
    end

    it "raises when the underlying method returns false" do
      writer.result = false

      expect { writer.cancel! }.to raise_error(DhanHQ::OrderError, /TestWriter#cancel failed/)
    end

    it "includes the instance's validation errors in the message" do
      writer.result = false
      writer.errors = { quantity: ["is missing"] }

      expect { writer.cancel! }.to raise_error(/quantity/)
    end
  end

  describe "overridability" do
    it "lets a hand-written bang method override the generated one and call super" do
      subclass = Class.new(writer_class) do
        def self.place!(*args, **kwargs)
          super
        rescue DhanHQ::OrderError
          :rescued_in_subclass
        end
      end
      subclass.class_result = nil

      expect(subclass.place!).to be(:rescued_in_subclass)
    end
  end

  describe "error_class option" do
    it "raises the requested class" do
      klass = Class.new do
        extend DhanHQ::Concerns::BangWrites

        def self.name = "PickyWriter"
        def self.configure = nil
        bang_class_writes :configure, error_class: DhanHQ::ValidationError
      end

      expect { klass.configure! }.to raise_error(DhanHQ::ValidationError)
    end
  end
end
