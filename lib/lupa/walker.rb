# frozen_string_literal: true

require "prism"

module Lupa
  # Visits one parsed file, collecting Nodes (class/module definitions) and raw
  # Edges whose `dst` is still an unresolved constant string. Resolution to real
  # node names is Extractor's job.
  class Walker < Prism::Visitor
    CALL_METHODS    = %w[call call!].freeze
    ENQUEUE_METHODS = %w[perform_later perform_async perform_now perform_in perform_at].freeze
    ASSOCIATIONS    = %w[has_many has_one belongs_to has_and_belongs_to_many].freeze
    DYNAMIC_METHODS = %w[constantize safe_constantize].freeze
    DELIVER_METHODS = %w[deliver_later deliver_now].freeze

    # ActiveRecord lifecycle callback macros. Each wires a lifecycle event to a
    # method — almost always a same-class symbol, which is not a node, so we
    # record it as a `triggers` marker (see macro_edge) rather than an edge to a
    # constant. Explicit list to avoid catching lookalikes (after_sign_in_path_for).
    CALLBACK_METHODS = %w[
      before_validation after_validation
      before_save around_save after_save after_save_commit
      before_create around_create after_create after_create_commit
      before_update around_update after_update after_update_commit
      before_destroy around_destroy after_destroy after_destroy_commit
      before_commit after_commit after_rollback
      after_initialize after_find after_touch
    ].freeze

    # Constant-receiver methods too ubiquitous to be useful as `invokes` edges:
    # the ActiveRecord query/persistence surface plus `.new`. Recording these
    # would bury the business-logic class-method calls we actually want under a
    # firehose of `Model.find` / `Model.where`. Tunable — err toward dropping.
    NOISY_METHODS = %w[
      new find find! find_by find_by! find_each find_in_batches where where! not
      all none first last second take pluck ids exists? any? many? count size sum
      average minimum maximum create create! build update update! update_all
      insert insert_all upsert upsert_all destroy destroy_all delete delete_all
      order reorder includes preload eager_load joins left_joins references
      select distinct group having limit offset unscoped from lock readonly
      find_or_create_by find_or_create_by! find_or_initialize_by first_or_create
    ].freeze

    attr_reader :nodes, :edges

    def initialize(file:, kind:)
      @file = file
      @kind = kind
      @nodes = []
      @edges = []
      @scope = []
      @consumed = {} # call-node object_ids folded into an enclosing edge (see mailer_edge)
      super()
    end

    # Dotted string for a constant node, e.g. "Api::FooController".
    def self.const_string(node)
      case node
      when Prism::ConstantReadNode then node.name.to_s
      when Prism::ConstantPathNode
        [const_string(node.parent), node.name].compact.join("::")
      end
    end

    # Rough Rails classify: :chart_notes -> "ChartNote".
    def self.classify(sym)
      singular = sym.to_s.sub(/s\z/, "")
      singular.split("_").map(&:capitalize).join
    end

    def visit_module_node(node)
      @scope.push(self.class.const_string(node.constant_path))
      mkind = @file.include?("/concerns/") ? "concern" : "module"
      @nodes << Node.new(current, mkind, @file, node.location.start_line)
      super
      @scope.pop
    end

    def visit_class_node(node)
      @scope.push(self.class.const_string(node.constant_path))
      @nodes << Node.new(current, @kind, @file, node.location.start_line)
      if (sc = node.superclass) && (s = self.class.const_string(sc))
        @edges << Edge.new(current, "inherits", s, sc.location.start_line)
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
      return if current.empty?
      return if @consumed.delete(node.object_id) # the mailer-action call behind a deliver_*

      name = node.name.to_s
      return if mailer_edge(node, name)
      return if dynamic_edge(node, name)
      return if macro_edge(node, name)

      handoff_edge(node, name)
    end

    # Mailer.action(...).deliver_later / .deliver_now — a mail send. Record it as
    # an `emails` edge to the mailer class and mark the mailer-action call so it
    # doesn't also surface as a redundant `invokes` on the same expression.
    def mailer_edge(node, name)
      return false unless DELIVER_METHODS.include?(name)

      mailer = mailer_receiver(node.receiver)
      return false unless mailer

      @consumed[node.receiver.object_id] = true if node.receiver.is_a?(Prism::CallNode)
      add(node, "emails", mailer)
      true
    end

    # The constant a mailer-send chain roots at, unwrapping the `.action` / `.with`
    # calls between the deliver and the mailer. nil if it isn't a constant.
    def mailer_receiver(recv)
      case recv
      when Prism::ConstantReadNode, Prism::ConstantPathNode then self.class.const_string(recv)
      when Prism::CallNode then mailer_receiver(recv.receiver)
      end
    end

    # Const.constantize / expr.safe_constantize — the target is computed at
    # runtime, so we can't resolve it. Record a `dispatches` marker keyed on the
    # receiver's source so a chain forks visibly here instead of ending silently.
    def dynamic_edge(node, name)
      return false unless DYNAMIC_METHODS.include?(name) && node.receiver

      label = node.receiver.slice.gsub(/\s+/, " ")
      @edges << Edge.new(current, "dispatches", label[0, 80], node.location.start_line)
      true
    end

    # include/organize/association macros — targets come from the arguments.
    def macro_edge(node, name)
      if %w[include prepend extend].include?(name)
        each_const_arg(node) { |c| add(node, "includes", c) }
      elsif name == "organize"
        each_const_arg(node) { |c| add(node, "organizes", c) }
      elsif ASSOCIATIONS.include?(name)
        target = association_target(node)
        add(node, "association", target) if target
      elsif CALLBACK_METHODS.include?(name)
        each_symbol_arg(node) { |m| add(node, "triggers", m) }
      else
        return false
      end
      true
    end

    # An explicit `class_name:` wins over the naming convention (that guess is
    # wrong whenever the two differ). `polymorphic: true` has no single target,
    # so drop it rather than invent one. Otherwise classify the association name.
    def association_target(node)
      opts = keyword_args(node)
      return nil if opts["polymorphic"].is_a?(Prism::TrueNode)
      return const_literal(opts["class_name"]) if opts.key?("class_name")

      sym = first_symbol_arg(node)
      self.class.classify(sym) if sym
    end

    # Symbol-keyed keyword arguments of a call, as { "key" => value_node }.
    def keyword_args(node)
      last = node.arguments&.arguments&.last
      return {} unless last.is_a?(Prism::KeywordHashNode) || last.is_a?(Prism::HashNode)

      last.elements.each_with_object({}) do |el, acc|
        next unless el.is_a?(Prism::AssocNode) && el.key.is_a?(Prism::SymbolNode)

        acc[el.key.unescaped] = el.value
      end
    end

    # The constant name a string/symbol literal names, e.g. 'Ephemeral::Patient'.
    def const_literal(node)
      node.unescaped if node.is_a?(Prism::StringNode) || node.is_a?(Prism::SymbolNode)
    end

    # Const.<method> — target is the receiver constant. `.call`/`.call!` are the
    # interactor handoff (`calls`), the perform_* family is `enqueues`, and any
    # other non-noisy class-method call is a generic `invokes`. Resolution later
    # drops receivers that aren't repo constants, so Time/Rails/etc. never stick.
    def handoff_edge(node, name)
      recv = node.receiver
      return unless recv.is_a?(Prism::ConstantReadNode) || recv.is_a?(Prism::ConstantPathNode)

      rel = rel_for(name)
      add(node, rel, self.class.const_string(recv)) if rel
    end

    def rel_for(name)
      if CALL_METHODS.include?(name) then "calls"
      elsif ENQUEUE_METHODS.include?(name) then "enqueues"
      elsif NOISY_METHODS.include?(name) then nil
      else "invokes"
      end
    end

    def add(node, rel, const)
      @edges << Edge.new(current, rel, const, node.location.start_line)
    end

    def each_const_arg(node)
      node.arguments&.arguments&.each do |arg|
        c = self.class.const_string(arg)
        yield c if c
      end
    end

    def first_symbol_arg(node)
      arg = node.arguments&.arguments&.first
      arg.unescaped.to_sym if arg.is_a?(Prism::SymbolNode)
    end

    # Positional symbol arguments only — `after_save :a, :b, if: :cond` yields
    # "a" and "b", never the `if:` option's value (a keyword hash, not a symbol).
    def each_symbol_arg(node)
      node.arguments&.arguments&.each do |arg|
        yield arg.unescaped if arg.is_a?(Prism::SymbolNode)
      end
    end
  end
end
