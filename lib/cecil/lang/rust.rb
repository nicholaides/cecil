require_relative "../../cecil"

module Cecil
  module Lang
    class Rust < Code
      # Overrides to use 4 spaces for indentation
      def indent_chars = "    "

      # Overrides to ignore ambiguous indentation
      def handle_ambiguous_indentation = Cecil::Indentation::Ambiguity.ignore

      module Helpers
        # Short for "list"; Accepts one or a list of strings and returns them joined with `", "`
        #
        # @param items [Array[#to_s], #to_s] One or a list of objects that respond to `#to_s`
        # @return [String] The stringified inputs concatenated with `", "`
        def l(items) = Array(items).compact.join(", ")

        # Escapes codepoint as unicode character literal
        # See https://doc.rust-lang.org/reference/tokens.html#unicode-escapes
        def unicode_escape_codepoint(char_int) = "\\u{#{char_int.to_s(16)}}"

        # Escapes string as unicode character literals
        def unicode_escape(str) = str.each_codepoint.map { unicode_escape_codepoint(_1) }.join

        # According to https://doc.rust-lang.org/reference/tokens.html#ascii-escapes
        CHAR_TO_CUSTOM_ESCAPE_LITERAL = {
          "\n" => '\n',
          "\r" => '\r',
          "\t" => '\t',
          "\0" => '\0',
          "\\" => "\\\\", # \ => \\
          '"' => '\\"'    # " => \"
        }.freeze

        # Escapes a character (string with one character) for use in a Rust string literal.
        #
        # @example
        #   rchar("\n") # => \n
        #   rchar('"')  # => \"
        #   rchar('😉') # => \u{1f609}
        def rchar(char)
          CHAR_TO_CUSTOM_ESCAPE_LITERAL[char] ||
            case char
            when /^[ -~]$/ then char
            else unicode_escape(char)
            end
        end

        # Short for "string content"; returns escaped version of the string that can be inserted into a
        # string literal.
        #
        # Useful for inserting data into a string or for outputting a string but using quotes to make it clear to the
        # reader what the intended output will be.
        #
        # @example Inserting into a string literal
        #   name = %q{Bob "the Machine" O'Brian}
        #   `let admin = "$name (Admin)";`[s name]
        #
        #   # outputs:
        #   # let admin = "Bob \"the Machine\" O\'Brian (Admin)";
        #
        # @param val [#to_s] A string or any object that responds to `#to_s`
        # @return [String] A JSON string without quotes
        def s(val) = val.each_char.map { rchar(_1) }.join

        # short for "rust value"; returns a Rust literal version of the input.
        #
        # Currently handles strings, integers, floats, and booleans.
        #
        # @example
        #   `let name = $name;`[rs "Bob \"the Machine\" O\'Brian (Admin)"]
        #   `let age = $age;`[rs 42]
        #   `let friendliness = $friendliness;`[rs 9.9]
        #   `let is_admin = $is_admin;`[rs true]
        #
        #   # outputs:
        #   # let name = "Bob \"the Machine\" O\'Brian (Admin)";
        #   # let age = 42;
        #   # let friendliness = 9.9;
        #   # let is_admin = true;
        def rs(val)
          case val
          in String then %("#{s val}")
          in Integer | Float | true | false then val.to_s
          end
        end
      end
    end
  end
end
