# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # Devise's own route table, transcribed from `lib/devise/rails/routes.rb`
      # and `lib/devise/mapping.rb` at the version in the host app's
      # Gemfile.lock. Devise declares these as Rails `resource` calls, but two
      # of the five are not plain REST — sessions is `only: []` plus three
      # custom member routes, and registrations renames `new` and adds
      # `cancel` — so the shapes are listed here rather than squeezed through
      # RouteResource.
      #
      # An entry is [verb, segments, action]. A Symbol segment is a key into
      # `path_names`, so an app that renames `sign_in` moves the path with it;
      # a String is literal.
      module Routes
        # The sign-out route is `via: mapping.sign_out_via`, whose default is
        # `:delete`. An app that changes it is under-reported, not misread.
        SIGN_OUT_VIA = "DELETE"

        TABLE = {
          "sessions" => [
            ["GET", [:sign_in], "new"],
            ["POST", [:sign_in], "create"],
            [SIGN_OUT_VIA, [:sign_out], "destroy"]
          ],
          "passwords" => [
            ["GET", [:password, "new"], "new"],
            ["POST", [:password], "create"],
            ["GET", [:password, "edit"], "edit"],
            ["PATCH", [:password], "update"],
            ["PUT", [:password], "update"]
          ],
          "confirmations" => [
            ["GET", [:confirmation, "new"], "new"],
            ["POST", [:confirmation], "create"],
            ["GET", [:confirmation], "show"]
          ],
          "unlocks" => [
            ["GET", [:unlock, "new"], "new"],
            ["POST", [:unlock], "create"],
            ["GET", [:unlock], "show"]
          ],
          "registrations" => [
            ["GET", %i[registration sign_up], "new"],
            ["POST", [:registration], "create"],
            ["GET", %i[registration edit], "edit"],
            ["PATCH", [:registration], "update"],
            ["PUT", [:registration], "update"],
            ["DELETE", [:registration], "destroy"],
            ["GET", %i[registration cancel], "cancel"]
          ]
        }.freeze

        # `path_names` is a Hash defaulting each key to its own name, which
        # makes most segments self-naming. `:registration` is the one Devise
        # overrides to empty, so registrations hang off the mount root.
        DEFAULTS = { "registration" => "" }.freeze

        module_function

        # @param role [String] a `controllers:` key, e.g. "sessions"
        # @param path_names [Hash{String => String}] the mount's path_names: overrides
        # @return [Array<Array(String, String, String)>] [verb, path suffix, action]
        def expand(role, path_names)
          TABLE.fetch(role, []).map do |verb, segments, action|
            [verb, render(segments, path_names), action]
          end
        end

        # @return [String] the segments joined, empty ones dropped
        def render(segments, path_names)
          segments.map { |segment| resolve(segment, path_names) }.reject(&:empty?).join("/")
        end

        def resolve(segment, path_names)
          return segment unless segment.is_a?(Symbol)

          path_names.fetch(segment.to_s) { DEFAULTS.fetch(segment.to_s, segment.to_s) }
        end
      end
    end
  end
end
