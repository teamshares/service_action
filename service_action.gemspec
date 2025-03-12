# frozen_string_literal: true

require_relative "lib/service_action/version"

Gem::Specification.new do |spec|
  spec.name = "service_action"
  spec.version = ServiceAction::VERSION
  spec.authors = ["Kali Donovan"]
  spec.email = ["kali@teamshares.com"]

  spec.summary = "Pattern for writing callable service objects"
  spec.description = "Contract validation and error swallowing wrappers around Interactor"
  spec.homepage = "https://github.com/teamshares/service-action"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/teamshares/service_action/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "activemodel", "> 7.0" # For contract validation
  spec.add_dependency "activesupport", "> 7.0" # For compact_blank and friends
  spec.add_dependency "interactor", "3.1.2" # Organize business logic into interactors
end
