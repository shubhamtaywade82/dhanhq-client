# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in DhanHQ.gemspec
gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop", "~> 1.21"

gem "rubocop-rake", "~> 0.6.0"

gem "rubocop-rspec", "~> 3.2"

gem "webmock", "~> 3.24"

gem "yard", "~> 0.9.37"

# Dependencies for yard server (required in Ruby 3.0+)
gem "rack", "~> 2.0", groups: %i[development]
gem "webrick", "~> 1.7", groups: %i[development]

gem "debug"

gem "rubycritic"

gem "rubocop-performance"

gem "vcr"

gem "dotenv", groups: %i[development test]

gem "simplecov", "~> 0.22", require: false, groups: %i[development test]

group :test do
  gem "timecop"
end

# Optional tools for local technical analysis experiments (not part of the gem)
group :tools do
  gem "ruby-technical-analysis"
  gem "technical-analysis"
end
