# frozen_string_literal: true

module Lupa
  # SQL literal helpers shared by the dump writer and the query builders. We
  # shell out to the sqlite3 binary (no bound parameters), so every value that
  # reaches a statement goes through here.
  module Sql
    LIKE_ESCAPE = "\\"

    module_function

    # @param value [#to_s]
    # @return [String] a single-quoted SQL string literal, e.g. 'O''Brien'
    def quote(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end

    # @param value [#to_s] matched literally inside a LIKE pattern
    # @return [String] value with LIKE wildcards (% and _) escaped
    def like_literal(value)
      value.to_s.gsub(/[\\%_]/) { |char| "#{LIKE_ESCAPE}#{char}" }
    end
  end
end
