# frozen_string_literal: true

require "logger"

# DhanHQ exposes configuration helpers and global client settings.
module DhanHQ
  class << self
    # keep whatever you already have; add these if missing:
    attr_accessor :client_id, :access_token, :base_url, :ws_version

    # default logger so calls like DhanHQ.logger&.info never explode
    def logger
      @logger ||= Logger.new($stdout, level: Logger::INFO)
    end

    attr_writer :logger

    # same API style as your README
    def configure
      yield self
      # ensure a logger is present even if user didn’t set one
      self.logger ||= Logger.new($stdout, level: Logger::INFO)
    end

    # if you support env bootstrap
    def configure_with_env
      self.client_id    = ENV.fetch("CLIENT_ID", nil)
      self.access_token = ENV.fetch("ACCESS_TOKEN", nil)
      self.base_url     = ENV.fetch("DHAN_BASE_URL", "https://api.dhan.co/v2")
      self.ws_version   = ENV.fetch("DHAN_WS_VERSION", 2).to_i
    end
  end
end
