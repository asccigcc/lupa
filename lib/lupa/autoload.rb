# frozen_string_literal: true

module Lupa
  # Which constant Rails' autoloader would load from a file. Each `app/*`
  # directory is an autoload root, and so is a `concerns` directory inside one,
  # which is why `app/models/concerns/trackable.rb` defines `Trackable` and not
  # `Concerns::Trackable`.
  module Autoload
    ROOT = %r{\Aapp/[^/]+/(?:concerns/)?}

    module_function

    # @param path [String] repo-relative file path
    # @return [String, nil] e.g. "Task::Configurator"; nil outside an app/ root
    def constant_for(path)
      return nil unless path.match?(ROOT)

      segments(path).map { |segment| Inflector.camelize(segment) }.join("::")
    end

    def segments(path)
      path.sub(ROOT, "").delete_suffix(".rb").split("/")
    end
  end
end
