# frozen_string_literal: true

module Lupa
  # A repository root and where lupa keeps its graph for it.
  class Repo
    DB_RELATIVE = "tmp/lupa.db"

    def initialize(path = Dir.pwd)
      @root = File.expand_path(path)
    end

    attr_reader :root

    def db
      File.join(@root, DB_RELATIVE)
    end
  end
end
