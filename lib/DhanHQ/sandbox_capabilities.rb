# frozen_string_literal: true

module DhanHQ
  # Endpoint-level capability matrix for the Dhan sandbox host
  # (https://sandbox.dhan.co/v2), **derived from the contracts** rather than
  # hand-maintained: an operation is sandbox-supported exactly when the
  # vendored sandbox OpenAPI document (contracts/dhanhq/sandbox.openapi.json,
  # captured from sandbox.dhan.co/v2/v3/api-docs) serves it.
  #
  # The sandbox mirrors only a subset of the live v2 surface — 27 of 71
  # operations in the current contract. Requests to anything outside that
  # subset fail with an opaque 404/405 (or DH-905), so the client raises a
  # clear {DhanHQ::SandboxUnsupportedError} instead when the resolved target
  # host is the sandbox. Use mode +:hybrid+ (live market data + sandbox
  # execution) or an +environment_overrides+ entry to keep those tiers on
  # production.
  #
  # This matrix is generated from the contract at boot; the conformance spec
  # cross-checks the derivation against both vendored documents, so a spec
  # update automatically moves the matrix.
  module SandboxCapabilities
    class << self
      # True when the sandbox host cannot serve this method+path combination.
      #
      # Unknown endpoints (no contract operation matches) are unsupported —
      # fail closed, because the sandbox serves a strict subset of live.
      #
      # @param method [Symbol, String] HTTP verb of the request
      # @param path [String] Request path as built by the resource layer
      # @return [Boolean]
      def unsupported?(method, path)
        !Contract::Registry.sandbox_supported?(method, path)
      end

      # Human-readable explanation of why a path is unavailable on sandbox,
      # for inclusion in error messages. Returns nil for supported endpoints.
      #
      # @param method [Symbol, String]
      # @param path [String]
      # @return [String, nil]
      def reason_for(method, path)
        verb = method.to_s.downcase.to_sym
        return nil if Contract::Registry.sandbox_supported?(verb, path)

        op = Contract::Registry.resolve(verb, path)
        if op
          "operation #{op.label} is not part of the sandbox API surface " \
            "(sandbox.dhan.co/v2 serves #{Contract::Registry.sandbox_operation_ids.size} " \
            "of the #{Contract::Registry.operations.size} contract operations)"
        else
          "no contract operation matches #{verb.to_s.upcase} #{path} — the endpoint is " \
            "absent from both the live and sandbox OpenAPI documents (see REVIEW.md M1)"
        end
      end
    end
  end
end
