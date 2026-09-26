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
    USAGE = <<~USAGE.freeze
      lupa — static code-interaction graph for AI agents.

        lupa scan [PATH]     build/refresh the graph for a repo (default: cwd)
        lupa query "SQL"     run a SQL query against the repo's graph
        lupa callers NAME    who calls/enqueues/includes/inherits NAME
        lupa calls NAME      what NAME calls/enqueues/organizes
        lupa where NAME      where NAME is defined
        lupa stats           node/edge counts

      The graph lives in <repo>/#{Repo::DB_RELATIVE}. Requires the sqlite3 binary.
    USAGE

    # @param argv [Array<String>] command and arguments
    # @param out [IO] where results go
    # @param err [IO] where errors go
    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    # @return [Integer] process exit status
    def run
      send(command_for(argv.shift))
      0
    rescue Error => e
      err.puts(e.message)
      1
    end

    private

    attr_reader :argv, :out, :err

    def command_for(command)
      return :help if HELP.include?(command)

      DISPATCH[command] or raise Error, "lupa: unknown command #{command.inspect} (try: lupa help)"
    end

    def query   = run_sql(fetch_arg)
    def callers = run_sql(Queries.callers(fetch_arg))
    def calls   = run_sql(Queries.calls(fetch_arg))
    def where   = run_sql(Queries.where(fetch_arg))

    def scan
      repo = Repo.new(argv.shift || Dir.pwd)
      files = SourceFiles.new(repo.root)
      result = Extractor.call(files:)
      load_graph(repo.db, SqlDump.call(result))
      report_scan(files.label, result, repo.db)
    end

    def load_graph(db, sql)
      FileUtils.mkdir_p(File.dirname(db))
      sqlite(db, stdin: sql)
    end

    def report_scan(label, result, db)
      out.puts "lupa: scanned #{label} — nodes=#{result.nodes.size} edges=#{result.edges.size}"
      out.puts "lupa: skipped #{result.skipped.size} unparseable: #{result.skipped.join(", ")}" if result.skipped.any?
      out.puts "lupa: graph written to #{db}"
    end

    def stats
      out.puts "nodes by kind:"
      run_sql(Queries.stats_nodes)
      out.puts
      out.puts "edges by rel:"
      run_sql(Queries.stats_edges)
    end

    def run_sql(sql)
      out.print(sqlite("-column", "-header", db_path, sql))
    end

    def sqlite(*, stdin: "")
      stdout, stderr, status = Open3.capture3("sqlite3", *, stdin_data: stdin)
      raise Error, "lupa: sqlite3 failed: #{stderr.strip}" unless status.success?

      stdout
    rescue Errno::ENOENT
      raise Error, "lupa: the sqlite3 binary is not installed"
    end

    def db_path
      db = Repo.new.db
      return db if File.exist?(db)

      raise Error, "lupa: no graph at #{db} — run 'lupa scan' in the repo first."
    end

    def fetch_arg
      argv.shift || raise(Error, "lupa: this command needs a name argument")
    end

    def help = out.puts(USAGE)
  end
end
