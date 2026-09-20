# frozen_string_literal: true

require "fileutils"
require "open3"

module Lupa
  # Command-line front end. Thin glue: it builds the graph via Extractor/SqlDump
  # and shells out to the `sqlite3` binary for storage and queries (no sqlite3
  # gem dependency). The interesting logic lives in Extractor and Queries.
  class CLI
    DB_RELATIVE = "tmp/lupa.db"

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      command = @argv.shift
      case command
      when "scan"           then scan(@argv.first)
      when "query"          then run_sql(fetch_arg)
      when "callers"        then run_sql(Queries.callers(fetch_arg))
      when "calls"          then run_sql(Queries.calls(fetch_arg))
      when "where"          then run_sql(Queries.where(fetch_arg))
      when "stats"          then stats
      when nil, "help", "-h", "--help" then help
      else raise Error, "lupa: unknown command #{command.inspect} (try: lupa help)"
      end
      0
    rescue Error => e
      @err.puts(e.message)
      1
    end

    private

    def scan(path)
      root = File.expand_path(path || Dir.pwd)
      db = File.join(root, DB_RELATIVE)
      FileUtils.mkdir_p(File.dirname(db))

      result = Extractor.call(root: root)
      _out, err, status = Open3.capture3("sqlite3", db, stdin_data: SqlDump.call(result))
      raise Error, "lupa: sqlite3 load failed: #{err}" unless status.success?

      @out.puts "lupa: scanned #{result.scan_label} — " \
                "nodes=#{result.nodes.size} edges=#{result.edges.size}"
      @out.puts "lupa: graph written to #{db}"
    end

    def stats
      @out.puts "nodes by kind:"
      run_sql(Queries.stats_nodes)
      @out.puts
      @out.puts "edges by rel:"
      run_sql(Queries.stats_edges)
    end

    def run_sql(sql)
      system("sqlite3", "-column", "-header", db_path, sql) ||
        raise(Error, "lupa: sqlite3 query failed (is the sqlite3 binary installed?)")
    end

    def db_path
      db = File.join(Dir.pwd, DB_RELATIVE)
      return db if File.exist?(db)

      raise Error, "lupa: no graph at #{db} — run 'lupa scan' in the repo first."
    end

    def fetch_arg
      @argv.shift || raise(Error, "lupa: this command needs a name argument")
    end

    def help
      @out.puts <<~USAGE
        lupa — static code-interaction graph for AI agents.

          lupa scan [PATH]     build/refresh the graph for a repo (default: cwd)
          lupa query "SQL"     run a SQL query against the repo's graph
          lupa callers NAME    who calls/enqueues/includes/inherits NAME
          lupa calls NAME      what NAME calls/enqueues/organizes
          lupa where NAME      where NAME is defined
          lupa stats           node/edge counts

        The graph lives in <repo>/#{DB_RELATIVE}. Requires the sqlite3 binary.
      USAGE
    end
  end
end
