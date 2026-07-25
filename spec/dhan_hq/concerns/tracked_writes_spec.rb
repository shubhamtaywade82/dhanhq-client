# frozen_string_literal: true

RSpec.describe DhanHQ::Concerns::TrackedWrites do
  # A stand-in for a model, so these examples describe the observation behaviour rather
  # than any one model's request plumbing.
  let(:writer_class) do
    Class.new do
      extend DhanHQ::Concerns::TrackedWrites
      extend DhanHQ::Concerns::BangWrites

      class << self
        attr_accessor :class_result
      end

      def self.name
        "TrackedWriter"
      end

      def self.place(*_args, **_kwargs)
        class_result
      end

      track_class_writes :place
      bang_class_writes :place

      attr_accessor :result

      def cancel
        @result
      end

      track_writes :cancel
    end
  end

  before do
    DhanHQ.configure do |config|
      config.client_id = "1000000001"
      config.access_token = "test-token"
      config.warn_on_ambiguous_write_failure = true
    end
    DhanHQ::Deprecation.reset!
    allow(DhanHQ.logger).to receive(:warn)
  end

  after do
    DhanHQ.reset_configuration!
    DhanHQ::Deprecation.reset!
  end

  describe "observation only" do
    it "returns nil unchanged" do
      writer_class.class_result = nil

      expect(writer_class.place).to be_nil
    end

    it "returns false unchanged" do
      writer = writer_class.new
      writer.result = false

      expect(writer.cancel).to be(false)
    end

    it "returns a success value unchanged" do
      writer_class.class_result = :placed

      expect(writer_class.place).to be(:placed)
    end

    it "never raises" do
      writer_class.class_result = nil

      expect { writer_class.place }.not_to raise_error
    end

    it "forwards arguments to the real method" do
      allow(writer_class).to receive(:class_result).and_return(:placed)

      expect(writer_class.place(1, mode: :limit)).to be(:placed)
    end
  end

  describe "what it reports" do
    it "warns when a class write returns nil" do
      writer_class.class_result = nil

      writer_class.place

      expect(DhanHQ.logger).to have_received(:warn).with(/TrackedWriter\.place reported failure as nil/)
    end

    it "warns when an instance write returns false" do
      writer = writer_class.new
      writer.result = false

      writer.cancel

      expect(DhanHQ.logger).to have_received(:warn).with(/TrackedWriter#cancel reported failure as false/)
    end

    it "names an ErrorObject failure as such" do
      writer_class.class_result = DhanHQ::ErrorObject.new({ errorMessage: "nope" })

      writer_class.place

      expect(DhanHQ.logger).to have_received(:warn).with(/reported failure as a DhanHQ::ErrorObject/)
    end

    it "points the reader at the bang variant and the 4.0.0 change" do
      writer_class.class_result = nil

      writer_class.place

      expect(DhanHQ.logger).to have_received(:warn).with(/TrackedWriter\.place! .*4\.0\.0|4\.0\.0.*place!/m)
    end

    it "says nothing on success" do
      writer_class.class_result = :placed

      writer_class.place

      expect(DhanHQ.logger).not_to have_received(:warn)
    end

    it "warns once per call site, not once per failure" do
      writer_class.class_result = nil

      5.times { writer_class.place }

      expect(DhanHQ.logger).to have_received(:warn).once
    end
  end

  describe "interaction with the bang variants" do
    # A caller who has already migrated to place! should not be told to migrate.
    it "stays silent when the failure is reached through the bang variant" do
      writer_class.class_result = nil

      expect { writer_class.place! }.to raise_error(DhanHQ::OrderError)
      expect(DhanHQ.logger).not_to have_received(:warn)
    end

    it "resumes warning for direct calls after a bang call" do
      writer_class.class_result = nil

      expect { writer_class.place! }.to raise_error(DhanHQ::OrderError)
      writer_class.place

      expect(DhanHQ.logger).to have_received(:warn).once
    end

    it "leaves suppression off after the bang variant raises" do
      writer_class.class_result = nil

      expect { writer_class.place! }.to raise_error(DhanHQ::OrderError)

      expect(DhanHQ::WriteResult).not_to be_suppressed
    end
  end

  describe "opting out" do
    it "says nothing when the flag is off" do
      DhanHQ.configuration.warn_on_ambiguous_write_failure = false
      writer_class.class_result = nil

      writer_class.place

      expect(DhanHQ.logger).not_to have_received(:warn)
    end

    it "still returns the same value when the flag is off" do
      DhanHQ.configuration.warn_on_ambiguous_write_failure = false
      writer_class.class_result = nil

      expect(writer_class.place).to be_nil
    end
  end
end
