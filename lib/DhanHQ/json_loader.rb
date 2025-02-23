# frozen_string_literal: true

require "json"

module DhanHQ
  module JSONLoader
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
