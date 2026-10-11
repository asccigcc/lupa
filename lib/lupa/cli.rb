# frozen_string_literal: true

module Lupa
  # Command-line front end. Thin glue: each command turns arguments into SQL
  # (Queries) or builds the graph (Extractor/SqlDump), hands it to Sqlite, and
  # prints what comes back. No logic of its own beyond argument handling.
  class CLI
    DISPATCH = {
      "scan" => :scan, "query" => :query, "callers" => :callers,
      "calls" => :calls, "impact" => :impact, "path" => :path, "where" => :where, "stats" => :stats
    }.freeze
    HELP = [nil, "help", "-h", "--help"].freeze
    USAGE = <<~USAGE.freeze
      lupa — static code-interaction graph for AI agents.

        lupa scan [PATH]     build/refresh the graph for a repo (default: cwd)
        lupa query "SQL"     run a SQL query against the repo's graph
        lupa callers NAME    who calls/enqueues/includes/inherits NAME
        lupa calls NAME      what NAME calls/enqueues/organizes
        lupa impact NAME     everything one hop from NAME, in and out, with file:line
        lupa path FROM TO    the shortest chains of edges from FROM to TO
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

    def query   = print_table(fetch_arg)
    def callers = print_table(Queries.callers(fetch_arg))
    def calls   = print_table(Queries.calls(fetch_arg))
    def where   = print_table(Queries.where(fetch_arg))
    def impact  = print_table(Queries.impact(fetch_arg))

    def path
      from = fetch_arg
      to = fetch_arg
      trails = Path.new(graph.rows(Queries.path_edges)).between(from, to)
      out.puts(trails.empty? ? "lupa: no path from #{from} to #{to} within #{Path::MAX_HOPS} hops" : trails)
    end

    def scan
      repo = Repo.new(argv.shift || Dir.pwd)
      files = SourceFiles.new(repo.root)
      result = Extractor.call(files:)
      Sqlite.new(repo.db).load_script(SqlDump.call(result))
      report_scan(files.label, result, repo.db)
    end

    def report_scan(label, result, db)
      out.puts "lupa: scanned #{label} — nodes=#{result.nodes.size} edges=#{result.edges.size}"
      out.puts "lupa: skipped #{result.skipped.size} unparseable: #{result.skipped.join(", ")}" if result.skipped.any?
      out.puts "lupa: graph written to #{db}"
    end

    def stats
      out.puts "nodes by kind:"
      print_table(Queries.stats_nodes)
      out.puts
      out.puts "edges by rel:"
      print_table(Queries.stats_edges)
    end

    def print_table(sql) = out.print(graph.table(sql))

    # Every command but `scan` reads a graph that must already be there.
    def graph
      db = Repo.new.db
      raise Error, "lupa: no graph at #{db} — run 'lupa scan' in the repo first." unless File.exist?(db)

      Sqlite.new(db)
    end

    def fetch_arg
      argv.shift || raise(Error, "lupa: this command needs a name argument")
    end

    def help = out.puts(USAGE)
  end
end
