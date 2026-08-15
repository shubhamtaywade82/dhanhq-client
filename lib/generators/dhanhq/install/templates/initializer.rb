# frozen_string_literal: true

require "dhan_hq"

if (creds = Rails.application.credentials.dig(:dhanhq))
  ENV["DHAN_CLIENT_ID"]    ||= creds[:client_id]
  ENV["DHAN_ACCESS_TOKEN"] ||= creds[:access_token]
end

DhanHQ.configure_with_env

log_level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase
DhanHQ.logger.level = Logger.const_get(log_level)

# Full optional configuration (base_url, ws_order_url, partner auth, timeouts,
# DHAN_WS_DEBUG, ...) is documented in:
#   https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/CONFIGURATION.md
#   https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/RAILS_INTEGRATION.md
