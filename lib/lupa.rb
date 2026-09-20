# frozen_string_literal: true

require "zeitwerk"

module Lupa
  class Error < StandardError; end
end

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.ignore("#{__dir__}/lupa/version.rb") # defines a constant, not a class
loader.setup

require_relative "lupa/version"
