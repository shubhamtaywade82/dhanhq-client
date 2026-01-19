# frozen_string_literal: true

require_relative "lib/DhanHQ/version"

Gem::Specification.new do |spec|
  spec.name = "DhanHQ"
  spec.version = DhanHQ::VERSION
  spec.authors = ["Shubham Taywade"]
  spec.email = ["shubhamtaywade82@gmail.com"]

  spec.summary = "DhanHQ is a simple CLI for DhanHQ API."
  spec.description = "DhanHQ is a simple CLI for DhanHQ API."
  spec.homepage = "https://github.com/shubhamtaywade82/dhanhq-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client"
  spec.metadata["changelog_uri"] = "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
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
  spec.add_dependency "faraday"
  spec.add_dependency "faraday_middleware"
  spec.add_dependency "faye-websocket"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
