# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

# TODO: Kali -- re-enable rubocop once I've reorganized files and ported over the set we actually care about
# task default: %i[spec rubocop]
task default: %i[spec]
