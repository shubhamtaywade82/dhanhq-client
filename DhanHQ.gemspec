# frozen_string_literal: true

require_relative "lib/DhanHQ/version"

Gem::Specification.new do |spec|
  spec.name = "DhanHQ"
  spec.version = DhanHQ::VERSION
  spec.authors = ["Shubham Taywade"]
  spec.email = ["shubhamtaywade82@gmail.com"]

  spec.summary = "The Ruby SDK for Dhan API v2 with REST, WebSocket, and trading workflows."
  spec.description = "A production-grade Ruby SDK for Dhan API v2 built for algo trading, " \
                     "portfolio monitoring, and live trading systems. Provides typed models, " \
                     "token lifecycle management, dry-validation contracts, resilient WebSocket " \
                     "streaming, and safety-focused order workflows for Ruby applications."
  spec.homepage = "https://github.com/shubhamtaywade82/dhanhq-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client"
  spec.metadata["changelog_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/CHANGELOG.md"

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
  spec.add_dependency "activesupport"
  spec.add_dependency "base64"
  spec.add_dependency "bindata"
  spec.add_dependency "concurrent-ruby"
  spec.add_dependency "csv"
  spec.add_dependency "dry-validation"
  spec.add_dependency "eventmachine"
  spec.add_dependency "faraday", "~> 2.14"
  spec.add_dependency "faye-websocket"
  spec.add_dependency "rotp"
  spec.add_dependency "zeitwerk"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
