# frozen_string_literal: true

module Lupa
  # The gem conventions lupa understands, beyond Rails' own.
  #
  # An integration is inert unless the app actually uses the gem: every hook is
  # keyed on that gem's own vocabulary (`devise`, `devise_for`), so a repo
  # without it matches nothing and records nothing. That is why there is no
  # detection step and nothing to configure.
  #
  # An integration answers any of:
  #
  #   recognizers       call shapes in Ruby files, as Walker's own
  #   route_recognizers call shapes in routes files
  #
  # both being `call(node, recorder) -> Boolean`, and it writes what it finds
  # through the recorder like anything else. A gem's conventions are often
  # app-specific — Devise's helper names depend on which models call `devise` —
  # so a recognizer *declares* what it found (`recorder.declare`) and the
  # app-wide picture is assembled after the walk.
  module Integrations
    ALL = [Devise].freeze

    module_function

    # @return [Array<#call>] recognizers for Ruby files
    def recognizers = hook(:recognizers)

    # @return [Array<#call>] recognizers for routes files
    def route_recognizers = hook(:route_recognizers)

    # The accessors the app's gems generate, as [accessor, model, owner]
    # triples for AccessorIndex. A declaration takes part by answering
    # `accessors`; one that doesn't is here for another phase.
    # @param declarations [Array<Object>] everything the walk declared
    def accessors(declarations)
      declarations.select { |found| found.respond_to?(:accessors) }.flat_map(&:accessors)
    end

    def hook(name)
      ALL.select { |gem| gem.respond_to?(name) }.flat_map(&name)
    end
  end
end
