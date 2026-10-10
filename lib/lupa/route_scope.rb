# frozen_string_literal: true

module Lupa
  # The routing context a RouteWalker is inside: the controller-module prefix
  # (from `namespace` / `scope module:`), the path prefix (from `namespace`,
  # `scope "path"` and enclosing resources), the controller a bare verb
  # belongs to and the enclosing resource. Owns how a route target string
  # becomes a controller constant.
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
      @controllers = []
    end

    # @param mod [String, nil] controller module to prefix, e.g. "Admin"
    # @param path [String, nil] path segment to prefix, e.g. "admin"
    # @param controller [String, nil] default controller, e.g. from `scope controller: :pages`
    def within(mod: nil, path: nil, controller: nil, &)
      enter(modules, mod) { enter(paths, path && Segment.new(path)) { enter(controllers, controller, &) } }
    end

    # Routes declared in a resource's block hang off it: nested under its
    # :resource_id unless a `member` / `collection` says otherwise.
    # @param resource [RouteResource]
    def nest(resource, &)
      enter(resources, resource) do
        enter(paths, resource) { within(controller: resource.controller) { enter(modes, "nested", &) } }
      end
    end

    # @param mode [String, nil] "member" or "collection"; nil, or no enclosing
    #   resource, leaves the path as it is
    def on(mode, &)
      enter(modes, resource && mode, &)
    end

    # @return [RouteResource, nil] the innermost enclosing resource
    def resource = resources.last

    # @return [String, nil] the innermost enclosing resource's or scope's controller
    def default_controller = controllers.last

    # "patients/registrations#store" -> "Patients::RegistrationsController",
    # prefixed by the enclosing modules unless the path is absolute (/...). An
    # empty controller ("#answers") is the namespace's own, as in Rails.
    # @return [String, nil]
    def controller(target)
      path = target.to_s.split("#").first.to_s
      parts = (path.start_with?("/") ? [] : modules) + path.split("/").reject(&:empty?).map { Inflector.camelize(_1) }
      "#{parts.join("::")}Controller" unless parts.empty?
    end

    # @return [String] the path under the enclosing prefixes, e.g. "admin/widgets/:widget_id/parts"
    def path(segment)
      (paths.map { |frame| render(frame) } + [segment.to_s.delete_prefix("/")]).reject(&:empty?).join("/")
    end

    private

    attr_reader :modules, :paths, :resources, :modes, :controllers

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
