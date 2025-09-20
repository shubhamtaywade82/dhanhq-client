# frozen_string_literal: true

require "digest"
require "fileutils"

module DhanHQ
  module WS
    class SingletonLock
      def initialize(token:, client_id:)
        key = Digest::SHA256.hexdigest("#{client_id}:#{token}")[0, 12]
        @path = File.expand_path("tmp/dhanhq_ws_#{key}.lock", Dir.pwd)
        FileUtils.mkdir_p(File.dirname(@path))
        @fh = File.open(@path, File::RDWR | File::CREAT, 0o644)
      end

      def acquire!
        unless @fh.flock(File::LOCK_NB | File::LOCK_EX)
          pid = begin
            @fh.read.to_i
          rescue StandardError
            nil
          end
          raise "Another DhanHQ WS process is active (pid=#{pid}). Stop it first."
        end
        @fh.rewind
        @fh.truncate(0)
        @fh.write(Process.pid.to_s)
        @fh.flush
        true
      end

      def release!
        @fh.flock(File::LOCK_UN)
        @fh.close
        begin
          File.delete(@path)
        rescue StandardError
          nil
        end
      end
    end
  end
end
