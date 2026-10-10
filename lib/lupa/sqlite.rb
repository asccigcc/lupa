# frozen_string_literal: true

require "fileutils"
require "open3"

module Lupa
  # The graph's storage, and the one place that knows the `sqlite3` binary.
  # lupa shells out instead of depending on the sqlite3 gem, which would make
  # every app that installs lupa build a native extension. Every way the
  # external command can fail is translated to Lupa::Error here, so the rest of
  # the code only passes SQL in and reads text out.
  class Sqlite
    TABLE = %w[-column -header].freeze
    TAB = ["-separator", "\t"].freeze

    # @param path [String] the database file; it need not exist yet
    def initialize(path)
      @path = path
    end

    # @return [String] the rows, aligned into columns under a header
    def table(sql) = run(*TABLE, path, sql)

    # Tab-separated: node names and rels never contain a tab.
    # @return [Array<Array<String>>] the rows, split into fields
    def rows(sql)
      run(*TAB, path, sql).lines(chomp: true).map { |row| row.split("\t") }
    end

    # Runs a script, creating the database and its directory if needed.
    def load_script(sql)
      FileUtils.mkdir_p(File.dirname(path))
      run(path, stdin: sql)
    end

    private

    attr_reader :path

    def run(*, stdin: "")
      stdout, stderr, status = Open3.capture3("sqlite3", *, stdin_data: stdin)
      raise Error, "lupa: sqlite3 failed: #{stderr.strip}" unless status.success?

      stdout
    rescue Errno::ENOENT
      raise Error, "lupa: the sqlite3 binary is not installed"
    end
  end
end
