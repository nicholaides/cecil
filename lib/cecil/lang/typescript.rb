require_relative "../../cecil"
require "json"

module Cecil
  module Lang
    class TypeScript < Code # rubocop:disable Style/Documentation
      # Overrides to use 2 spaces for indentation
      def indent_chars = "  "

      # Overrides to ignore ambiguous indentation
      def handle_ambiguous_indentation = Indentation::Ambiguity.ignore

      # Overrides to add support for closing multi-line comments (e.g. /* ... */)
      def block_ending_pairs = super.merge({ "/*" => "*/" })

      def placeholder_delimiting_pairs = super.merge({ '"' => '"' })

      def render(value, placeholder)
        # binding.irb if value == "John Doe"
        case placeholder.match.named_captures.transform_keys(&:to_sym)
        in pstart: '"', pend: '"'
          value.to_s.to_json
        else
          value.to_s
        end
      end

      module Helpers # rubocop:disable Style/Documentation
        include Code::Helpers

        # Short for "types"; Accepts one or a list of types and returns their union.
        #
        # @example
        #   the_types = ["Websocket", "undefined", "null"]
        #   `function register<$types>() {}`[t the_types]
        #
        #   # outputs:
        #   # function register<Websocket | undefined | null>() {}
        #
        # @param items [Array[#to_s], #to_s] One or a list of objects that respond to `#to_s`
        # @return [String] The stringified inputs concatenated with `" | "`
        def t(items) = Array(items).compact.join(" | ")

        # Short for "list"; Accepts one or a list of strings and returns them joined with `", "`
        #
        # Useful for:
        # - arrays
        # - objects
        # - function arguments
        #
        # @example
        #   the_classes = ["Websocket", "Array", "Function"]
        #   `register($args)`[l the_classes]
        #
        #   # outputs:
        #   # register(Websocket, Array, Function)
        #
        # @param items [Array[#to_s], #to_s] One or a list of objects that respond to `#to_s`
        # @return [String] The stringified inputs concatenated with `", "`
        def l(items) = Array(items).compact.join(", ")

        # Short for "json"; returns the JSON representation of the input.
        #
        # Useful for when you have a value in Ruby and you want it as a literal
        # value in the JavaScript/TypeScript source code.
        #
        # @example
        #   current_user = { name: "Bob" }
        #   `const user = $user_obj`[j current_user]
        #
        #   # outputs:
        #   # const user = {"name":"Bob"}
        #
        # @param item [#to_json] Any object that responds to `#to_json`
        # @return [String] JSON representation of the input
        def j(item) = item.to_json

        # Short for "string content"; returns escaped version of the string that can be inserted into a JavaScript
        # string literal or template literal.
        #
        # Useful for inserting data into a string or for outputting a string but using quotes to make it clear to the
        # reader what the intended output will be.
        #
        # It also escapes single quotes and backticks so that it can be inserted into single-quoted strings and string
        # templates.
        #
        # @example Inserting into a string literal
        #   name = %q{Bob "the Machine" O'Brian}
        #   `const admin = "$name (Admin)"`[s name]
        #
        #   # outputs:
        #   # const admin = "Bob \"the Machine\" O\'Brian (Admin)"
        #
        # @example Make your code communicate that a value will be a string
        #   name = %q{Bob "the Machine" O'Brian}
        #   `const admin = "$name"`[s name]
        #
        #   # We could use the `#j` helper, too, but `#s` and quotes makes it clearer that the value will be a string
        #   `const admin = $name`[j name]
        #
        # @param item [#to_s] A string or any object that responds to `#to_s`
        # @return [String] A JSON string without quotes
        def s(item) = item.to_s.to_json[1...-1].gsub(/['`\$]/) { "\\#{_1}" }
      end
    end
  end
end
