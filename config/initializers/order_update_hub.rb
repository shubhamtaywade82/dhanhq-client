# frozen_string_literal: true

if ENV["ENABLE_WS"] == "true"
  Rails.application.config.to_prepare do
    Live::OrderUpdateHub.instance.start!
    Rails.logger.info("[init] Live::OrderUpdateHub started")
  rescue StandardError => e
    Rails.logger.error("[init] OrderUpdateHub failed: #{e.class} #{e.message}")
  end

  at_exit do
    Live::OrderUpdateHub.instance.stop!
  rescue StandardError => e
    Rails.logger.warn("[exit] OrderUpdateHub stop failed: #{e.message}")
  end
end
