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

# Vendored-document sources. sandbox.dhan.co answers HTTP 403 to datacenter /
# CI egress (observed on GitHub Actions runners), so host unavailability is
# reported as "skipped" instead of failing the task; genuine content drift on
# any *reachable* host still fails `contract:check`.
CONTRACT_SPEC_SOURCES = {
  live: "https://api.dhan.co/v2/v3/api-docs",
  sandbox: "https://sandbox.dhan.co/v2/v3/api-docs"
}.freeze

# Raised when a vendor api-docs endpoint does not serve a usable document.
class ContractFetchError < StandardError; end

# @return [String] the raw spec body
# @raise [ContractFetchError] on non-200 or non-JSON responses
def fetch_contract_spec(name, url)
  require "net/http"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 10
  http.read_timeout = 30
  response = http.start do |session|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "dhanhq-client-contract-refresh (+https://github.com/shubhamtaywade82/dhanhq-client)"
    request["Accept"] = "application/json"
    session.request(request)
  end
  raise ContractFetchError, "#{name} spec download returned HTTP #{response.code}" unless response.code.to_i == 200

  body = response.body.to_s
  json = body.strip.start_with?("{")
  raise ContractFetchError, "#{name} spec download did not return JSON (#{body[0, 80].inspect})" unless json

  body
end

namespace :contract do
  desc "Re-download the DhanHQ OpenAPI documents and show the drift as a git diff"
  task :refresh do
    require "json"
    require "fileutils"

    changed = []
    unavailable = []
    CONTRACT_SPEC_SOURCES.each do |name, url|
      target = File.expand_path("contracts/dhanhq/#{name}.openapi.json", __dir__)
      begin
        body = fetch_contract_spec(name, url)
      rescue ContractFetchError => e
        unavailable << "#{name} (#{e.message})"
        next
      end

      current = File.exist?(target) ? JSON.parse(File.read(target)) : nil
      fresh = JSON.parse(body)
      if current == fresh
        puts "#{name}: unchanged"
      else
        File.write(target, "#{JSON.pretty_generate(fresh)}\n")
        changed << name
        puts "#{name}: UPDATED #{target}"
      end
    end

    unless unavailable.empty?
      warn "skipped unreachable hosts: #{unavailable.join(", ")}"
      warn "sandbox.dhan.co blocks datacenter/CI egress; download the JSON in a browser and"
      warn "replace contracts/dhanhq/{live,sandbox}.openapi.json manually, then re-run the contract specs."
    end

    if changed.any?
      puts
      puts "Drift detected in: #{changed.join(", ")}"
      puts "Review it with: git diff -- contracts/"
      puts "New operations must be bound or declared in lib/DhanHQ/contract/bindings.yml"
      puts "and rate-limit-classed in contracts/overlays/0002-rate-limit-annotations.jsonpatch."
      puts "Then run: bundle exec rspec spec/dhan_hq/contract/"
    else
      puts "No contract drift."
    end
  end

  desc "CI mode: fail when a fresh download differs from the vendored documents"
  task :check do
    require "json"

    drift = []
    unavailable = []
    CONTRACT_SPEC_SOURCES.each do |name, url|
      vendored = File.expand_path("contracts/dhanhq/#{name}.openapi.json", __dir__)
      begin
        body = fetch_contract_spec(name, url)
      rescue ContractFetchError => e
        unavailable << "#{name} (#{e.message})"
        next
      end

      fresh = JSON.parse(body)
      # Deep-compare PARSED documents: byte/serializer differences (key order,
      # unicode escaping, float formatting) are not contract drift — only
      # semantic content is.
      drift << name if fresh != JSON.parse(File.read(vendored))
    end

    unless unavailable.empty?
      warn "contract:check skipped unreachable hosts: #{unavailable.join(", ")}"
      warn "(sandbox.dhan.co answers HTTP 403 to datacenter/CI egress — known vendor behaviour;"
      warn " the weekly drift run still catches live-document drift, and sandbox drift when reachable)"
    end

    if drift.any?
      warn "CONTRACT DRIFT detected for: #{drift.join(", ")}."
      warn "Run `rake contract:refresh`, review `git diff -- contracts/`, then update"
      warn "bindings/overlays per contracts/overlays/README.md before releasing."
      exit 1
    end
    puts "Vendored contracts match the live api-docs endpoints."
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
end

task default: %i[spec rubocop]
