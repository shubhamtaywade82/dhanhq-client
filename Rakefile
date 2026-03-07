# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

# Single RuboCop task; the gem also registers rubocop:autocorrect and rubocop:autocorrect_all.
desc "Run RuboCop"
RuboCop::RakeTask.new(:rubocop)

task default: %i[spec rubocop]
