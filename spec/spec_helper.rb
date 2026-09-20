# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "lib/lupa/cli.rb" # thin IO glue that shells out to sqlite3
  minimum_coverage 90
end

require "lupa"

FIXTURE_REPO = File.expand_path("fixtures/repo", __dir__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
