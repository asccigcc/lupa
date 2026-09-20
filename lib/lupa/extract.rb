#!/usr/bin/env ruby
# frozen_string_literal: true

# lupa extractor entrypoint. Builds the interaction graph for a repo and prints
# a SQLite-loadable dump to stdout:
#
#   ruby extract.rb --root /path/to/repo | sqlite3 repo/tmp/lupa.db
#
# The real work lives in the testable classes under lib/lupa/.

require_relative "extractor"
require_relative "sql_dump"

root = Dir.pwd
if (i = ARGV.index("--root")) && ARGV[i + 1]
  root = ARGV[i + 1]
end

result = Lupa::Extractor.call(root: root)
puts Lupa::SqlDump.call(result)
warn "lupa: scanned #{result.scan_label} — nodes=#{result.nodes.size} edges=#{result.edges.size}"
