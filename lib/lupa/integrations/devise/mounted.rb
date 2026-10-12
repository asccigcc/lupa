# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # One `devise_for` declaration, read for the three things that decide its
      # routes: where it mounts, what it renames, and which roles it keeps.
      class Mounted
        SKIP_ALL = "all"

        # @param name [String] the plural name the mount is declared with, e.g. "patients"
        # @param options [Hash{String => Prism::Node}] the declaration's keyword args
        def initialize(name, options)
          @name = name
          @options = options
        end

        # `devise_for :patients, path: ""` mounts at the root, not under
        # /patients, so the path cannot be assumed from the name.
        # @return [String]
        def base
          Ast.literal(options["path"]) || name
        end

        # @return [Hash{String => String}] the path_names: overrides
        def path_names
          Ast.each_pair(options["path_names"]).to_h { |key, value| [key.to_s, Ast.literal(value).to_s] }
        end

        # Only a `controllers:` override points into the app. Devise's own
        # controllers live in the gem, so a role without an override has no
        # class here to point at.
        # @return [Hash{String => String}] role => target, e.g. "sessions" => "patients/sessions"
        def controllers
          Ast.each_pair(options["controllers"])
             .to_h { |role, value| [role.to_s, Ast.literal(value)] }
             .select { |role, target| target && used?(role) }
        end

        private

        attr_reader :name, :options

        # `only:` names what to keep, `skip:` what to drop, and `skip: :all`
        # drops every one.
        def used?(role)
          return only.include?(singular(role)) if options.key?("only")

          skipped != :all && !skipped.include?(singular(role))
        end

        def only = singulars("only")

        def skipped
          values = singulars("skip")
          values.include?(SKIP_ALL) ? :all : values
        end

        # Devise matches `only:`/`skip:` against singular module names
        # (`:registration`) while `controllers:` is keyed plurally
        # (`registrations:`), so both sides are singularized before they meet.
        def singulars(key)
          Ast.literals(options[key]).map { |value| singular(value) }
        end

        def singular(value) = Inflector.singularize(value)
      end
    end
  end
end
