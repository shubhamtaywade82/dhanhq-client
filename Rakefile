# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

# Single RuboCop task; the gem also registers rubocop:autocorrect and rubocop:autocorrect_all.
desc "Run RuboCop"
RuboCop::RakeTask.new(:rubocop)

# --------------------------------------------------------------------------
# Contract-first governance tasks (see CONTRACT_FIRST.md and
# contracts/overlays/README.md)
# --------------------------------------------------------------------------
namespace :contract do
  SPEC_SOURCES = {
    live: "https://api.dhan.co/v2/v3/api-docs",
    sandbox: "https://sandbox.dhan.co/v2/v3/api-docs"
  }.freeze

  desc "Re-download the DhanHQ OpenAPI documents and show the drift as a git diff"
  task :refresh do
    require "net/http"
    require "json"
    require "fileutils"

    changed = []
    SPEC_SOURCES.each do |name, url|
      target = File.expand_path("contracts/dhanhq/#{name}.openapi.json", __dir__)
      body = fetch_spec(name, url)
      next if body.nil?

      current = File.exist?(target) ? File.read(target) : nil
      pretty = JSON.pretty_generate(JSON.parse(body)) + "\n"
      if current == pretty
        puts "#{name}: unchanged"
      else
        File.write(target, pretty)
        changed << name
        puts "#{name}: UPDATED #{target}"
      end
    end

    if changed.any?
      puts
      puts "Drift detected in: #{changed.join(', ')}"
      puts "Review it with: git diff -- contracts/"
      puts "New operations must be bound or declared in lib/DhanHQ/contract/bindings.yml"
      puts "and rate-limit-classed in contracts/overlays/0002-rate-limit-annotations.jsonpatch."
      puts "Then run: bundle exec rspec spec/dhan_hq/contract/"
    else
      puts "No contract drift."
    end
  rescue FetchError => e
    warn "contract:refresh failed: #{e.message}"
    warn "The api-docs hosts are sometimes geo/UA-restricted; download the JSON in a"
    warn "browser and replace contracts/dhanhq/{live,sandbox}.openapi.json manually, then re-run the contract specs."
    exit 1
  end

  desc "CI mode: fail when a fresh download differs from the vendored documents"
  task :check do
    require "net/http"
    require "json"
    require "tmpdir"

    drift = []
    SPEC_SOURCES.each do |name, url|
      vendored = File.expand_path("contracts/dhanhq/#{name}.openapi.json", __dir__)
      body = fetch_spec(name, url)
      next if body.nil?

      fresh = JSON.pretty_generate(JSON.parse(body)) + "\n"
      drift << name if fresh != File.read(vendored)
    end

    if drift.any?
      warn "CONTRACT DRIFT detected for: #{drift.join(', ')}."
      warn "Run `rake contract:refresh`, review `git diff -- contracts/`, then update"
      warn "bindings/overlays per contracts/overlays/README.md before releasing."
      exit 1
    end
    puts "Vendored contracts match the live api-docs endpoints."
  rescue FetchError => e
    warn "contract:check could not download specs: #{e.message}"
    exit 1
  end

  desc "Regenerate lib/DhanHQ/contract/metadata.rb and docs/ENDPOINTS.md from the contract"
  task :generate do
    require_relative "lib/dhan_hq"
    DhanHQ::Contract::Generator.write_all!
    puts "Regenerated lib/DhanHQ/contract/metadata.rb and docs/ENDPOINTS.md."
  end

  desc "Offline property harness: schema-validate generated payloads for sandbox read-only operations"
  task :fuzz do
    require_relative "lib/dhan_hq"
    failures = DhanHQ::Contract::PropertyHarness.run!
    exit failures.zero? ? 0 : 1
  end

  desc "Generate docs/ENDPOINTS.md from the vendored contract"
  task :docs do
    require_relative "lib/dhan_hq"
    DhanHQ::Contract::Generator.write_endpoints_doc!
    puts "Regenerated docs/ENDPOINTS.md."
  end

  def fetch_spec(name, url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: 10, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "dhanhq-client-contract-refresh (+https://github.com/shubhamtaywade82/dhanhq-client)"
      request["Accept"] = "application/json"
      http.request(request)
    end
    raise FetchError, "#{name} spec download returned HTTP #{response.code}" unless response.code.to_i == 200
    unless response.body.to_s.strip.start_with?("{")
      raise FetchError, "#{name} spec download did not return JSON (#{response.body.to_s[0, 80].inspect})"
    end

    response.body
  end

  class FetchError < StandardError; end
end

task default: %i[spec rubocop]
