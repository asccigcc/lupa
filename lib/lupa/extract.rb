#!/usr/bin/env ruby
# frozen_string_literal: true

# lupa — static code-interaction graph extractor.
#
# Parses every Ruby file under a repo with Prism (no Rails boot) and emits a
# SQLite-loadable dump of how classes connect: which controller calls which
# interactor, which interactor organizes which steps, model associations, job
# enqueues, includes and inheritance. It lets an agent answer "what calls X /
# what does X call" with one SQL query instead of reading files.
#
# Only intra-repo edges are kept — a call whose receiver constant resolves to a
# class/module we define. Anything not statically resolvable (a call on a local
# variable, dynamic dispatch, a class_name: override) is dropped, not guessed,
# so the graph under-reports rather than lies.
#
# Usage:
#   ruby extract.rb --root /path/to/repo | sqlite3 repo/tmp/lupa.db

require "prism"

root = Dir.pwd
if (i = ARGV.index("--root")) && ARGV[i + 1]
  root = ARGV[i + 1]
end
root = File.expand_path(root)
# Prefer a Rails app/ dir; otherwise scan the whole repo.
scan_dir = File.directory?(File.join(root, "app")) ? File.join(root, "app") : root

# Directory names anywhere in a path that classify a file's role.
KIND_BY_DIR = {
  "controllers" => "controller",
  "interactors" => "interactor",
  "models"      => "model",
  "jobs"        => "job",
  "services"    => "service",
  "policies"    => "policy",
  "mailers"     => "mailer",
  "components"  => "component",
  "serializers" => "serializer",
}.freeze

CALL_METHODS    = %w[call call!].freeze
ENQUEUE_METHODS = %w[perform_later perform_async perform_now perform_in perform_at].freeze
ASSOCIATIONS    = %w[has_many has_one belongs_to has_and_belongs_to_many].freeze

# Skip vendored / generated trees that would only add noise.
SKIP = %r{/(vendor|node_modules|tmp|\.git|db/migrate|spec|test)/}

Node = Struct.new(:full, :kind, :file, :line)
Edge = Struct.new(:from, :rel, :to_const, :line, :to_full)

def kind_for(relpath)
  seg = relpath.split("/")
  KIND_BY_DIR.each { |dir, kind| return kind if seg.include?(dir) }
  "other"
end

def const_string(node)
  case node
  when Prism::ConstantReadNode then node.name.to_s
  when Prism::ConstantPathNode
    [const_string(node.parent), node.name].compact.join("::")
  end
end

def classify(sym)
  singular = sym.to_s.sub(/s\z/, "")
  singular.split("_").map(&:capitalize).join
end

class Walker < Prism::Visitor
  attr_reader :nodes, :edges

  def initialize(file, kind)
    @file = file
    @kind = kind
    @nodes = []
    @edges = []
    @scope = []
    super()
  end

  def visit_module_node(node)
    @scope.push(const_string(node.constant_path))
    full = @scope.join("::")
    mkind = @file.include?("/concerns/") ? "concern" : "module"
    @nodes << Node.new(full, mkind, @file, node.location.start_line)
    super
    @scope.pop
  end

  def visit_class_node(node)
    @scope.push(const_string(node.constant_path))
    full = @scope.join("::")
    @nodes << Node.new(full, @kind, @file, node.location.start_line)
    if (sc = node.superclass)
      s = const_string(sc)
      @edges << Edge.new(full, "inherits", s, sc.location.start_line) if s
    end
    super
    @scope.pop
  end

  def visit_call_node(node)
    record_call(node)
    super
  end

  private

  def current
    @scope.join("::")
  end

  def record_call(node)
    name = node.name.to_s

    if %w[include prepend extend].include?(name) && !current.empty?
      each_const_arg(node) { |c| @edges << Edge.new(current, "includes", c, node.location.start_line) }
      return
    end

    if name == "organize" && !current.empty?
      each_const_arg(node) { |c| @edges << Edge.new(current, "organizes", c, node.location.start_line) }
      return
    end

    if ASSOCIATIONS.include?(name) && !current.empty?
      sym = first_symbol_arg(node)
      @edges << Edge.new(current, "association", classify(sym), node.location.start_line) if sym
      return
    end

    recv = node.receiver
    return unless recv.is_a?(Prism::ConstantReadNode) || recv.is_a?(Prism::ConstantPathNode)
    return if current.empty?

    rel =
      if CALL_METHODS.include?(name) then "calls"
      elsif ENQUEUE_METHODS.include?(name) then "enqueues"
      end
    return unless rel

    @edges << Edge.new(current, rel, const_string(recv), node.location.start_line)
  end

  def each_const_arg(node)
    node.arguments&.arguments&.each do |arg|
      c = const_string(arg)
      yield c if c
    end
  end

  def first_symbol_arg(node)
    arg = node.arguments&.arguments&.first
    arg.unescaped.to_sym if arg.is_a?(Prism::SymbolNode)
  end
end

all_nodes = []
all_edges = []

Dir.glob(File.join(scan_dir, "**", "*.rb")).sort.each do |path|
  next if path.match?(SKIP)

  rel = path.delete_prefix(root + "/")
  result = Prism.parse(File.read(path))
  next if result.failure?

  walker = Walker.new(rel, kind_for(rel))
  result.value.accept(walker)
  all_nodes.concat(walker.nodes)
  all_edges.concat(walker.edges)
end

by_full  = {}
by_short = Hash.new { |h, k| h[k] = [] }
all_nodes.each do |n|
  by_full[n.full] = n
  by_short[n.full.split("::").last] << n.full
end

def resolve(const, by_full, by_short)
  return const if by_full.key?(const)

  candidates = by_short[const.split("::").last]
  candidates.first if candidates.size == 1
end

resolved = all_edges.filter_map do |e|
  target = resolve(e.to_const, by_full, by_short)
  next unless target

  e.to_full = target
  e
end

def sql_str(s)
  "'#{s.to_s.gsub("'", "''")}'"
end

puts "PRAGMA journal_mode=OFF;"
puts "BEGIN;"
puts "DROP TABLE IF EXISTS nodes;"
puts "DROP TABLE IF EXISTS edges;"
puts "CREATE TABLE nodes (name TEXT PRIMARY KEY, kind TEXT, file TEXT, line INTEGER);"
puts "CREATE TABLE edges (src TEXT, rel TEXT, dst TEXT, line INTEGER);"

all_nodes.uniq(&:full).each do |n|
  puts "INSERT OR IGNORE INTO nodes VALUES (#{sql_str(n.full)}, #{sql_str(n.kind)}, #{sql_str(n.file)}, #{n.line});"
end

resolved.uniq { |e| [e.from, e.rel, e.to_full, e.line] }.each do |e|
  puts "INSERT INTO edges VALUES (#{sql_str(e.from)}, #{sql_str(e.rel)}, #{sql_str(e.to_full)}, #{e.line});"
end

puts "CREATE INDEX idx_edges_src ON edges(src);"
puts "CREATE INDEX idx_edges_dst ON edges(dst);"
puts "COMMIT;"

warn "lupa: scanned #{scan_dir.delete_prefix(root + '/')} — nodes=#{all_nodes.uniq(&:full).size} edges=#{resolved.size} (raw=#{all_edges.size})"
