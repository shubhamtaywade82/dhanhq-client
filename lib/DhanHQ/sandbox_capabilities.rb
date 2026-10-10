# frozen_string_literal: true

module DhanHQ
  # Endpoint-level capability matrix for the Dhan sandbox host
  # (https://sandbox.dhan.co/v2), derived from the official sandbox OpenAPI
  # spec served at https://sandbox.dhan.co/v2/v3/api-docs.
  #
  # The sandbox mirrors only a subset of the live v2 surface. Requests to
  # anything outside that subset fail with an opaque 404/405 (or DH-905), so
  # the client raises a clear {DhanHQ::SandboxUnsupportedError} instead when
  # the resolved target host is the sandbox. Use mode +:hybrid+ (live market
  # data + sandbox execution) or an +environment_overrides+ entry to keep
  # those tiers on production.
  module SandboxCapabilities
    # Endpoint prefixes the sandbox does not implement. A +nil+ method matches
    # every HTTP verb; otherwise only the listed verb is blocked (e.g. POST
    # /v2/killswitch exists on the sandbox while GET /v2/killswitch does not,
    # and DELETE /v2/positions (exit-all) is absent while GET/POST work).
    UNAVAILABLE = [
      { method: nil, path: "/v2/super/orders" },          # Super orders: live only
      { method: nil, path: "/v2/alerts" },                # Conditional triggers + multi orders
      { method: nil, path: "/v2/pnlExit" },               # P&L based exit
      { method: nil, path: "/v2/ip" },                    # Static IP management
      { method: nil, path: "/v2/charts/rollingoption" },  # Expired options data
      { method: nil, path: "/v2/data" },                  # ScanX data APIs
      { method: nil, path: "/v2/marketfeed" },            # LTP/OHLC/quote snapshots
      { method: nil, path: "/v2/optionchain" },           # Option chain + expiry list
      { method: nil, path: "/v2/instrument" },            # Instrument master download
      { method: nil, path: "/v2/margincalculator/multi" }, # Multi-scrip margin
      { method: nil, path: "/v2/globalstocks" },          # US equities
      { method: :delete, path: "/v2/positions" },         # Exit-all positions
      { method: :get, path: "/v2/killswitch" }            # Kill switch status read
    ].freeze

    class << self
      # True when the sandbox host cannot serve this method+path combination.
      #
      # @param method [Symbol, String] HTTP verb of the request
      # @param path [String] Request path as built by the resource layer
      # @return [Boolean]
      def unsupported?(method, path)
        verb = method.to_s.downcase.to_sym
        UNAVAILABLE.any? do |rule|
          next false if rule[:method] && rule[:method] != verb

          path.start_with?(rule[:path])
        end
      end

      # Human-readable explanation of why a path is unavailable on sandbox,
      # for inclusion in error messages.
      #
      # @param method [Symbol, String]
      # @param path [String]
      # @return [String, nil]
      def reason_for(method, path)
        verb = method.to_s.downcase.to_sym
        rule = UNAVAILABLE.find do |r|
          next false if r[:method] && r[:method] != verb

          path.start_with?(r[:path])
        end
        return nil unless rule

        "endpoint #{verb.to_s.upcase} #{rule[:path]}* is not part of the sandbox API surface"
      end
    end
  end
end
