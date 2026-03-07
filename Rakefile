# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

# Standard check (no changes)
RuboCop::RakeTask.new(:rubocop)

# Safe autocorrect (replaces -a)
RuboCop::RakeTask.new(:"rubocop:fix") do |t|
  t.options = ["--autocorrect"]
end

# Aggressive autocorrect (replaces -A)
RuboCop::RakeTask.new(:"rubocop:fix_all") do |t|
  t.options = ["--auto-correct-all"]
end

task default: %i[spec rubocop]
