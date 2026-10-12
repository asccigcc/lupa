# frozen_string_literal: true

module Lupa
  # Picks the one definition that represents a constant. A class can be opened
  # in several files — `app/interactors/task/configurator.rb` says `class Task`
  # only to nest something under it — and the one that counts is the file the
  # autoloader would load the constant from, not whichever was read first.
  #
  # Reading order decided this before, so a wrapper in a directory that sorted
  # earlier could give a model the kind of an interactor, and every write to
  # that model was then dropped for not landing on one.
  module Definitions
    module_function

    # @param nodes [Array<Node>] every definition seen, in reading order
    # @return [Array<Node>] one per name, in first-seen order
    def call(nodes)
      nodes.group_by(&:name).map { |name, group| authoritative(name, group) }
    end

    # A pure namespace (`module Api`) has no file that spells it, and neither
    # does a route, so the first definition read stands.
    def authoritative(name, group)
      group.find { |node| Autoload.constant_for(node.file) == name } || group.first
    end
  end
end
