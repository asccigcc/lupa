# frozen_string_literal: true

require "fileutils"
require "open3"

module Lupa
  # Command-line front end. Thin glue: it builds the graph via Extractor/SqlDump
  # and shells out to the `sqlite3` binary for storage and queries (no sqlite3
  # gem dependency). The interesting logic lives in Extractor and Queries.
  class CLI
    DISPATCH = {
      "scan" => :scan, "query" => :query, "callers" => :callers,
      "calls" => :calls, "where" => :where, "stats" => :stats
    }.freeze
    HELP = [nil, "help", "-h", "--help"].freeze

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      send(command_for(@argv.shift))
      0
    rescue Error => e
      @err.puts(e.message)
      1
    end

    private

    def command_for(command)
      return :help if HELP.include?(command)

      DISPATCH[command] or raise Error, "lupa: unknown command #{command.inspect} (try: lupa help)"
    end

    def query   = run_sql(fetch_arg)
    def callers = run_sql(Queries.callers(fetch_arg))
    def calls   = run_sql(Queries.calls(fetch_arg))
    def where   = run_sql(Queries.where(fetch_arg))

    def scan
      repo = Repo.new(@argv.shift || Dir.pwd)
      result = Extractor.call(root: repo.root)
      load_graph(repo.db, SqlDump.call(result))

      @out.puts "lupa: scanned #{result.scan_label} — " \
                "nodes=#{result.nodes.size} edges=#{result.edges.size}"
      @out.puts "lupa: graph written to #{repo.db}"
    end

    def load_graph(db, sql)
      FileUtils.mkdir_p(File.dirname(db))
      _out, err, status = Open3.capture3("sqlite3", db, stdin_data: sql)
      raise Error, "lupa: sqlite3 load failed: #{err}" unless status.success?
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
      db = Repo.new.db
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

        The graph lives in <repo>/#{Repo::DB_RELATIVE}. Requires the sqlite3 binary.
      USAGE
    end
  end
end
