# frozen_string_literal: true

require_relative "lib/lupa/version"

Gem::Specification.new do |spec|
  spec.name        = "lupa"
  spec.version     = Lupa::VERSION
  spec.authors     = ["Pastorinni Ochoa"]
  spec.summary     = "Static code-interaction graph for Ruby/Rails, built for AI agents."
  spec.description = <<~DESC
    lupa parses a Ruby/Rails repo with Prism (no Rails boot) and stores how
    classes connect — controller-to-interactor calls, organizer steps, model
    associations, job enqueues, includes, inheritance — in a small SQLite graph,
    so an agent can answer "what calls X / what does X call" with one query
    instead of reading files. Only statically-resolvable intra-repo edges are
    kept; unresolved dispatch is dropped, not guessed. Ships a Claude skill.
  DESC
  spec.homepage    = "https://github.com/asccigcc/lupa"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "skill/**/*",
    "LICENSE",
    "README.md"
  ]
  spec.bindir        = "exe"
  spec.executables   = ["lupa"]
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", "~> 1.0"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }
end
