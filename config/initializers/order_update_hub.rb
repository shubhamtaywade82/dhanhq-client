# frozen_string_literal: true

if ENV["ENABLE_WS"] == "true"
  Rails.application.config.to_prepare do
    begin
      Live::OrderUpdateHub.instance.start!
      Rails.logger.info("[init] Live::OrderUpdateHub started")
    rescue => e
      Rails.logger.error("[init] OrderUpdateHub failed: #{e.class} #{e.message}")
    end
  end

  at_exit do
    begin
      Live::OrderUpdateHub.instance.stop!
    rescue => e
      Rails.logger.warn("[exit] OrderUpdateHub stop failed: #{e.message}")
    end
  end
end
