# frozen_string_literal: true

module Lupa
  # A small subset of ActiveSupport's inflections — enough to derive a model
  # constant from an association name without booting Rails. Only the last
  # snake_case segment inflects (`product_categories` -> `product_category`).
  module Inflector
    IRREGULAR = { "people" => "person", "children" => "child", "men" => "man", "women" => "woman" }.freeze
    UNCOUNTABLE = %w[series species equipment information news].freeze

    # First match wins. Words already singular (`status`, `address`) are kept
    # before the generic trailing-s strip can mangle them.
    SINGULAR_RULES = [
      [/(status|alias|bus|ss|is)\z/, '\1'],
      [/(status|alias|bus)es\z/, '\1'],
      [/(x|ch|sh|ss)es\z/, '\1'],
      [/([^aeiou])ies\z/, '\1y'],
      [/s\z/, ""]
    ].freeze

    module_function

    # @param word [String] snake_case, e.g. "chart_notes"
    # @return [String] e.g. "chart_note"
    def singularize(word)
      head, sep, last = word.to_s.rpartition("_")
      "#{head}#{sep}#{singular_word(last)}"
    end

    # @param word [String] snake_case, e.g. "chart_note"
    # @return [String] e.g. "ChartNote"
    def camelize(word)
      word.to_s.split("_").map(&:capitalize).join
    end

    def singular_word(word)
      return word if UNCOUNTABLE.include?(word)

      IRREGULAR.fetch(word) { apply_rule(word) }
    end

    def apply_rule(word)
      rule, replacement = SINGULAR_RULES.find { |pattern, _| word.match?(pattern) }
      rule ? word.sub(rule, replacement) : word
    end
  end
end
