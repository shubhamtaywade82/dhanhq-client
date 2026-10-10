# frozen_string_literal: true

require "spec_helper"

# The executable conformance suite: GAP_ANALYSIS.md made testable.
#
# These specs enforce the three-way contract between
#   1. the gem's resource layer (code),
#   2. lib/DhanHQ/contract/bindings.yml (the declared link), and
#   3. the vendored OpenAPI documents (contracts/dhanhq/*.openapi.json).
# Drift in any of the three fails here — before it fails a user's order.
RSpec.describe DhanHQ::Contract::Bindings do
  let(:registry) { DhanHQ::Contract::Registry }
  let(:live_ops) { registry.operations }
  let(:sandbox_raw_ids) do
    doc = DhanHQ::Contract::SpecLoader.load(:sandbox)
    doc.fetch("paths", {}).flat_map { |_p, item| item.values }
       .select { |o| o.is_a?(Hash) && o["operationId"] }
       .map { |o| o.fetch("operationId") }.to_set
  end

  describe "bindings table" do
    it "binds every listed method to a real live operationId" do
      broken = []
      described_class.table.each do |resource, methods|
        methods.each do |method, op_id|
          broken << "#{resource}##{method} -> #{op_id}" unless live_ops.key?(op_id)
        end
      end

      expect(broken).to be_empty, "bindings point to unknown operations: #{broken.join(', ')}"
    end

    it "does not bind the same operation from two resources" do
      dupes = described_class.all_operation_ids
                            .tally.select { |_id, count| count > 1 }.keys

      expect(dupes).to be_empty, "operations bound more than once: #{dupes.join(', ')}"
    end

    it "references resource classes and methods that actually exist" do
      missing = []
      described_class.table.each do |resource_name, methods|
        begin
          klass = DhanHQ.const_get(resource_name)
        rescue NameError
          missing << resource_name
          next
        end
        next unless klass.is_a?(Class)

        methods.each_key do |method|
          missing << "#{resource_name}##{method}" unless klass.method_defined?(method) || klass.private_method_defined?(method)
        end
      end

      expect(missing).to be_empty, "bindings reference missing code: #{missing.join(', ')}"
    end
  end

  describe "completeness" do
    it "accounts for every live operation as bound or explicitly unbound" do
      bound = described_class.all_operation_ids.to_set
      declared_unbound = described_class.unbound_operations.keys.to_set
      unaccounted = live_ops.keys.to_set - bound - declared_unbound

      expect(unaccounted).to be_empty,
                         "operations with no binding and no declared reason: #{unaccounted.sort.join(', ')}"
    end

    it "does not declare unbound reasons for operations that ARE bound" do
      bound = described_class.all_operation_ids.to_set
      overlap = described_class.unbound_operations.keys.to_set & bound

      expect(overlap).to be_empty
    end

    it "asserts that unmapped gem endpoints really resolve to nothing" do
      mismatches = described_class.unmapped_gem_endpoints.reject do |entry|
        registry.resolve(entry[:verb] || entry["verb"], entry[:path] || entry["path"]).nil?
      end

      expect(mismatches).to be_empty,
        "these gem endpoints now match a contract operation — move them into the bindings table: " \
        "#{mismatches.map { |m| "#{m[:verb] || m['verb']} #{m[:path] || m['path']}" }.join(', ')}"
    end
  end

  describe "operation metadata" do
    it "assigns a known rate-limit class to every operation" do
      valid = DhanHQ::RateLimiter::RATE_LIMITS.keys
      unclassed = live_ops.values.select { |op| !valid.include?(op.rate_limit_class) }

      expect(unclassed).to be_empty,
        "operations without a rate-limit class (overlay 0002): #{unclassed.map(&:label).join(', ')}"
    end

    it "marks every overlay operation as docs-only" do
      overlay_ops = live_ops.values.select(&:docs_only?)

      expect(overlay_ops.map(&:id).sort).to eq(
        %w[getProfile getinstrumentlist marketfeedLTP marketfeedOHLC
           marketfeedQuote optionchain optionchainexpirylist renewToken]
      )
    end

    it "keeps docs-only operations off the sandbox unless a VCR cassette verified them" do
      verified = %w[getProfile] # sandbox overlay 0004 (recorded 200 on sandbox.dhan.co/v2)

      live_ops.values.select(&:docs_only?).each do |op|
        expected = verified.include?(op.id)
        expect(op.sandbox_supported?).to eq(expected), "#{op.id}: expected sandbox_supported?=#{expected}"
      end
    end

    it "derives sandbox support from the raw sandbox document" do
      mismatches = live_ops.values.select do |op|
        op.sandbox_supported? != sandbox_raw_ids.include?(op.id)
      end

      expect(mismatches).to be_empty
    end

    it "keeps the sandbox surface a subset of the live surface" do
      extra = sandbox_raw_ids - live_ops.keys.to_set

      expect(extra).to be_empty,
        "sandbox document serves operations the live contract lacks: #{extra.sort.join(', ')}"
    end

    it "keeps request-key styles within the supported set" do
      styles = DhanHQ::Contract::Operation::PARAM_STYLES.values + [DhanHQ::Contract::Operation::DEFAULT_PARAM_STYLE]
      bad = live_ops.values.reject { |op| styles.include?(op.param_style) }

      expect(bad).to be_empty
    end
  end
end
