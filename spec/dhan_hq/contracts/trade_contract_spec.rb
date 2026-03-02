# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contracts::TradeContract do
  describe "contract definition" do
    it "is a subclass of BaseContract" do
      expect(described_class.superclass).to eq(DhanHQ::Contracts::BaseContract)
    end

    it "is a subclass of Dry::Validation::Contract" do
      expect(described_class.ancestors).to include(Dry::Validation::Contract)
    end

    # TradeContract intentionally defines no params schema — it serves as a
    # documentation placeholder for GET-only trade endpoints that require no
    # input validation.  Attempting to instantiate it raises SchemaMissingError.
    it "raises SchemaMissingError when instantiated (no params block defined)" do
      expect { described_class.new }.to raise_error(Dry::Validation::SchemaMissingError)
    end
  end
end
