# frozen_string_literal: true

require "json"

module DhanHQ
  # Utility for loading canned JSON fixtures bundled with the gem.
  module JSONLoader
    # Loads and symbolises a JSON request payload from the `requests/` folder.
    #
    # @param file [String] Relative path to the fixture file.
    # @return [Hash] Parsed JSON payload with symbolised keys.
    def self.load(file)
      file_path = File.expand_path("requests/#{file}", __dir__)
      JSON.parse(File.read(file_path), symbolize_names: true)
    rescue Errno::ENOENT
      puts "File not found: #{file_path}"
      {}
    rescue JSON::ParserError
      puts "Invalid JSON format in #{file_path}"
      {}
    end
  end
end
