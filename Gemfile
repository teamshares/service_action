# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in axn.gemspec
gemspec

gem "pry-byebug", "3.10.1"
gem "rspec", "~> 3.2"
gem "sidekiq", "~> 8" # Background job processor -- when update, ensure `process_context_to_sidekiq_args` is still compatible

gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"

# TODO: will need this in .gemspec if we want downstream consumers to have access
gem "interactor", github: "kaspermeyer/interactor", branch: "fix-hook-inheritance"
