# frozen_string_literal: true

require_relative "lib/DhanHQ/version"

Gem::Specification.new do |spec|
  spec.name = "DhanHQ"
  spec.version = DhanHQ::VERSION
  spec.authors = ["Shubham Taywade"]
  spec.email = ["shubhamtaywade82@gmail.com"]

  spec.summary = "Production-grade Ruby SDK for Dhan API v2 with REST APIs, WebSocket market data, token lifecycle management, dry-validation contracts and trading workflows."
  spec.description = "A production-grade Ruby SDK and Ruby client for Dhan API v2 built for algorithmic " \
                     "trading, portfolio monitoring, and live trading systems on NSE, BSE and MCX. " \
                     "Provides typed models, token lifecycle management, dry-validation contracts, " \
                     "resilient WebSocket streaming with auto-reconnect, and safety-focused order " \
                     "workflows for Ruby on Rails and standalone Ruby applications."
  spec.homepage = "https://shubhamtaywade82.github.io/dhanhq-client/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = "https://shubhamtaywade82.github.io/dhanhq-client/"
  spec.metadata["source_code_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client"
  spec.metadata["changelog_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://shubhamtaywade82.github.io/dhanhq-client/"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Files shipped in the released gem.
  #
  # This is an allowlist on purpose. The previous reject-list shipped anything tracked
  # that did not match a known-bad prefix, which meant a stray 36 MB core dump and a
  # 17 MB diagram.html — 51 MB of a 52 MB gem — went out in releases. An allowlist
  # cannot leak an unanticipated artifact: a new file is only published if a maintainer
  # adds its directory here.
  # `skills/` is the Claude Agent Skill pack (SKILL.md, references, examples,
  # helper scripts) that ships with the gem as product content, not build output.
  shipped_directories = %w[lib exe sig config docs skills].freeze
  shipped_root_files = %w[README.md CHANGELOG.md ARCHITECTURE.md GUIDE.md LICENSE.txt
                          CODE_OF_CONDUCT.md AGENTS.md].freeze
  # Draft PR write-ups live under docs/ but are not user documentation.
  excluded_patterns = [%r{\Adocs/PR_}].freeze

  tracked = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end || []

  spec.files = tracked.select do |path|
    next false if excluded_patterns.any? { |pattern| path.match?(pattern) }

    shipped_root_files.include?(path) ||
      shipped_directories.any? { |dir| path.start_with?("#{dir}/") }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime Dependencies
  #
  # Every one of these was previously unpinned (`add_dependency "x"` with no
  # version at all, equivalent to `>= 0`) except faraday. That's not a
  # theoretical risk: forcing a fresh `bundle install` under Ruby 3.1.6 while
  # investigating #55 demonstrated it twice over on this exact gemspec --
  # dry-validation resolved to 0.4.1 (a 2016-era, pre-Contract-DSL API every
  # contract in lib/DhanHQ/contracts/ is incompatible with) and, once that was
  # pinned, activesupport resolved to 7.2.3.2 and broke ToolRegistry,
  # MCP::Server, and Risk::Pipeline -- 63 failures with no relation to Ruby
  # version syntax at all. `>= 0` doesn't just mean "any version we've tested
  # ever" -- to a resolver under different constraints, it means "any version
  # that has ever existed, including ones from a decade before this gem's
  # current API."
  #
  # Floors below match each gem's currently locked major (Gemfile.lock),
  # i.e. "don't silently fall back below what CI actually exercises" --
  # not a claim that some exact lower version was individually verified.
  # activesupport and dry-validation are the two with concrete evidence
  # (above); the pessimistic `~>` on dry-validation intentionally still
  # allows every 1.x release, not just 1.11 -- a plain `~> 1.11` locks to
  # `>= 1.11, < 1.12` and would block 1.12+ patch releases, which was a
  # mistake in how this was first pinned.
  spec.add_dependency "activesupport", ">= 8.0"
  spec.add_dependency "base64", ">= 0.1"
  spec.add_dependency "bindata", ">= 2.4"
  spec.add_dependency "concurrent-ruby", ">= 1.3"
  spec.add_dependency "csv", ">= 3.0"
  spec.add_dependency "dry-validation", "~> 1.0"
  spec.add_dependency "eventmachine", ">= 1.2"
  spec.add_dependency "faraday", "~> 2.14"
  spec.add_dependency "faye-websocket", ">= 0.11"
  spec.add_dependency "rotp", ">= 6.0"
  spec.add_dependency "zeitwerk", ">= 2.6"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
