# frozen_string_literal: true

module Lupa
  # Per-file accumulator a RouteWalker writes into — the routes counterpart of
  # Recorder. It names the route node after the verb, the full path and the
  # action ("GET /widgets/:id #show"), since the edge itself only carries the
  # controller. A target that names no controller (a redirect, a proc) records
  # nothing: the route goes somewhere lupa can't name.
  class RouteRecorder
    attr_reader :nodes, :edges

    # @param scope [RouteScope] turns a route's path and target into the full
    #   path and the controller constant
    # @param file [String] repo-relative path of the routes file
    def initialize(scope, file:)
      @scope = scope
      @file = file
      @nodes = []
      @edges = []
    end

    # @param route [Route] as declared, with its path relative to the scope
    # @param node [Prism::CallNode] the declaration, for its line
    def record(route, node)
      controller = scope.controller(route.target)
      add(label(route), controller, node.location.start_line) if controller
    end

    private

    attr_reader :scope, :file

    def label(route)
      "#{route.verb} /#{scope.path(route.path)}#{" ##{route.action}" if route.action}"
    end

    def add(label, controller, line)
      nodes << Node.new(label, "route", file, line)
      edges << Edge.new(src: label, rel: "routes", dst: controller, file:, line:)
    end
  end
end
