# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contract::PropertyHarness do
  it "exercises only sandbox-served, side-effect-free operations" do
    described_class::SAFE_OPERATIONS.each do |operation_id|
      operation = DhanHQ::Contract::Registry.operation(operation_id)
      expect(operation).not_to be_nil
      message = "#{operation_id} must be served by the sandbox to be a safe property target"
      expect(operation).to be_sandbox_supported, message

      # Belt and braces: nothing that mutates account state may enter the list.
      expect(operation.path).not_to match(%r{/(orders|positions|holdings|edis|pnlExit|killswitch|alerts)})
    end
  end

  it "holds the accept/reject properties for generated payloads" do
    failures = 0
    expect { failures = described_class.run!(out: StringIO.new) }.not_to raise_error
    expect(failures).to be_zero
  end
end
