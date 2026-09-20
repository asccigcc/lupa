# frozen_string_literal: true

module Lupa
  # A repository root and where lupa keeps its graph for it.
  class Repo
    DB_RELATIVE = "tmp/lupa.db"

    def initialize(path = Dir.pwd)
      @root = File.expand_path(path)
      @db = File.join(@root, DB_RELATIVE)
    end

    attr_reader :root, :db
  end
end
