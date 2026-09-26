# frozen_string_literal: true

module Lupa
  # The node kind implied by where a file lives: `app/models/x.rb` defines a
  # model, `app/models/concerns/y.rb` a concern. The single owner of that rule.
  class Kind
    BY_DIR = {
      "controllers" => "controller", "interactors" => "interactor",
      "models" => "model", "jobs" => "job", "services" => "service",
      "policies" => "policy", "mailers" => "mailer", "components" => "component",
      "serializers" => "serializer"
    }.freeze

    # @param path [String] repo-relative file path
    def initialize(path)
      @segments = path.split("/")
    end

    # @return [String] the kind of a class defined in this file
    def for_class
      BY_DIR.each { |dir, kind| return kind if segments.include?(dir) }
      "other"
    end

    # @return [String] the kind of a module defined in this file
    def for_module
      segments.include?("concerns") ? "concern" : "module"
    end

    private

    attr_reader :segments
  end
end
