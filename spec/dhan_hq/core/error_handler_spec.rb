# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::ErrorHandler do
  describe ".handle" do
    context "when passed a Dry::Validation::Result with errors" do
      let(:contract) do
        Class.new(Dry::Validation::Contract) do
          params { required(:name).filled(:string) }
        end.new
      end
      let(:result) { contract.call({}) } # missing :name → failure

      it "raises RuntimeError with 'Validation Error:' prefix" do
        expect { described_class.handle(result) }
          .to raise_error(RuntimeError, /Validation Error:/)
      end

      it "includes the field error key in the message" do
        expect { described_class.handle(result) }
          .to raise_error(RuntimeError, /name/)
      end
    end

    context "when passed a StandardError" do
      let(:error) { StandardError.new("something went wrong") }

      it "raises RuntimeError with 'Error:' prefix" do
        expect { described_class.handle(error) }
          .to raise_error(RuntimeError, /Error:.*something went wrong/)
      end
    end

    context "when passed a RuntimeError" do
      it "raises RuntimeError with the original message" do
        err = RuntimeError.new("runtime problem")
        expect { described_class.handle(err) }
          .to raise_error(RuntimeError, /runtime problem/)
      end
    end
  end
end
