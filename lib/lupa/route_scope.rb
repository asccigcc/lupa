# frozen_string_literal: true

module Lupa
  # The routing context a RouteWalker is inside: the controller-module prefix
  # (from `namespace` / `scope module:`) and the path prefix (from `namespace`).
  # Owns how a route target string becomes a controller constant.
  class RouteScope
    def initialize
      @modules = []
      @paths = []
    end

    # @param mod [String, nil] controller module to prefix, e.g. "Admin"
    # @param path [String, nil] path segment to prefix, e.g. "admin"
    def within(mod: nil, path: nil, &)
      enter(modules, mod) { enter(paths, path, &) }
    end

    # "patients/registrations#store" -> "Patients::RegistrationsController",
    # prefixed by the enclosing modules unless the path is absolute (/...).
    # @return [String, nil]
    def controller(target)
      path = target.to_s.split("#").first.to_s
      return if path.empty?

      prefix = path.start_with?("/") ? [] : modules
      "#{(prefix + path.split("/").reject(&:empty?).map { |s| Inflector.camelize(s) }).join("::")}Controller"
    end

    # @return [String] the path under the enclosing path prefixes, e.g. "admin/widgets"
    def path(segment)
      (paths + [segment.to_s.delete_prefix("/")]).reject(&:empty?).join("/")
    end

    private

    attr_reader :modules, :paths

    def enter(stack, value)
      return yield unless value

      stack.push(value)
      yield
      stack.pop
    end
  end
end
