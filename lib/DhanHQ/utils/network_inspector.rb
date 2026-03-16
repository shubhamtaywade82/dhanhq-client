# frozen_string_literal: true

require "net/http"
require "socket"

module DhanHQ
  module Utils
    # Collects network and environment metadata for order audit logging.
    #
    # Results are memoized at class level so that repeated calls within a single
    # process do not incur additional HTTP round-trips to the IP-lookup services.
    #
    # @example
    #   DhanHQ::Utils::NetworkInspector.public_ipv4  # => "122.171.22.40"
    #   DhanHQ::Utils::NetworkInspector.hostname     # => "DESKTOP-SHUBHAM"
    #   DhanHQ::Utils::NetworkInspector.environment  # => "production"
    class NetworkInspector
      IPV4_URI = URI("https://api.ipify.org")
      IPV6_URI = URI("https://api64.ipify.org")

      class << self
        # Returns the public IPv4 address of this machine.
        # Cached after the first successful lookup. Returns "unknown" on failure.
        #
        # @return [String]
        def public_ipv4
          @public_ipv4 ||= fetch_ip(IPV4_URI)
        end

        # Returns the public IPv6 address of this machine.
        # Cached after the first successful lookup. Returns "unknown" on failure.
        #
        # @return [String]
        def public_ipv6
          @public_ipv6 ||= fetch_ip(IPV6_URI)
        end

        # Returns the system hostname.
        #
        # @return [String]
        def hostname
          Socket.gethostname
        end

        # Returns the current runtime environment name.
        # Checks RAILS_ENV, RACK_ENV, APP_ENV in order; falls back to "unknown".
        #
        # @return [String]
        def environment
          ENV["RAILS_ENV"] || ENV["RACK_ENV"] || ENV["APP_ENV"] || "unknown"
        end

        # Clears the memoized IP cache (useful in tests or when the IP may change).
        #
        # @return [void]
        def reset_cache!
          @public_ipv4 = nil
          @public_ipv6 = nil
        end

        private

        def fetch_ip(uri)
          Net::HTTP.get(uri).strip
        rescue StandardError
          "unknown"
        end
      end
    end
  end
end
