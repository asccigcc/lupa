# frozen_string_literal: true

module Lupa
  # The routing context a RouteWalker is inside: the controller-module prefix
  # (from `namespace` / `scope module:`), the path prefix (from `namespace`,
  # `scope "path"` and enclosing resources) and the resource a bare verb belongs
  # to. Owns how a route target string becomes a controller constant.
  class RouteScope
    # A plain path prefix: it reads the same whatever the mode.
    Segment = Data.define(:text) do
      def segment(_mode) = text
    end

    def initialize
      @modules = []
      @paths = []
      @resources = []
      @modes = []
    end

    # @param mod [String, nil] controller module to prefix, e.g. "Admin"
    # @param path [String, nil] path segment to prefix, e.g. "admin"
    def within(mod: nil, path: nil, &)
      enter(modules, mod) { enter(paths, path && Segment.new(path), &) }
    end

    # Routes declared in a resource's block hang off it: nested under its
    # :resource_id unless a `member` / `collection` says otherwise.
    # @param resource [RouteResource]
    def nest(resource, &)
      enter(resources, resource) { enter(paths, resource) { enter(modes, "nested", &) } }
    end

    # @param mode [String, nil] "member" or "collection"; nil, or no enclosing
    #   resource, leaves the path as it is
    def on(mode, &)
      enter(modes, resource && mode, &)
    end

    # @return [RouteResource, nil] the innermost enclosing resource
    def resource = resources.last

    # "patients/registrations#store" -> "Patients::RegistrationsController",
    # prefixed by the enclosing modules unless the path is absolute (/...).
    # @return [String, nil]
    def controller(target)
      path = target.to_s.split("#").first.to_s
      return if path.empty?

      prefix = path.start_with?("/") ? [] : modules
      "#{(prefix + path.split("/").reject(&:empty?).map { |s| Inflector.camelize(s) }).join("::")}Controller"
    end

    # @return [String] the path under the enclosing prefixes, e.g. "admin/widgets/:widget_id/parts"
    def path(segment)
      (paths.map { |frame| render(frame) } + [segment.to_s.delete_prefix("/")]).reject(&:empty?).join("/")
    end

    private

    attr_reader :modules, :paths, :resources, :modes

    # Only the innermost resource can be re-rooted; outer ones always nest.
    def render(frame)
      frame.segment(frame.equal?(resource) ? modes.last : "nested")
    end

    def enter(stack, value)
      return yield unless value

      stack.push(value)
      yield
      stack.pop
    end
  end
end
