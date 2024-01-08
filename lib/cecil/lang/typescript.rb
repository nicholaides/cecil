require_relative "../../cecil"
require "json"

module Cecil
  module Lang
    class TypeScript < Code
      # Use 2 characters for indentation
      def indent_chars = "  "

      def handle_ambiguous_indentation = Indentation::Ambiguity.ignore

      module Helpers
        include Code::Helpers

        # "types". Accepts one or a list of types and returns their union.
        #
        # E.g. `t ["undefined", "object"]` returns `"undefined | object"
        # E.g. `t "undefined"` returns `"undefined"
        def t(items) = Array(items).join(" | ")

        # "list". Accepts one or a list of strings and returns them joined with ", "
        #
        # E.g. `l ["Websocket", "Array"]` returns "Websocket, Array"
        # E.g. `l "Websocket"` returns "Websocket"
        def l(items) = Array(items).join(", ")

        # "json". Returns the JSON representation of an object.
        #
        # Useful for when you have a value in Ruby and you want it as a literal
        # value in the TypeScript source code. E.g.:
        # `
        #   name = "Bob"
        #   `const username = $name`[j name]
        #
        #   outputs: `const username = "Bob"`
        # `
        def j(item) = item.to_json

        # "string content". Returns a JSON string without quotes.
        #
        # Useful for inserting data into a string:
        #  name = "Bob"
        # `const admin = "$name (Admin)"`[s name]
        #
        # outputs: `const admin = "Bob (Admin)"`
        #
        #
        # Also useful to make the template communicate more clearly that a value
        # will be a string. E.g.
        # `const username = "$name"`[s name]
        def s(item) = item.to_s.to_json[1...-1]
      end
    end
  end
end
