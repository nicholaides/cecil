require_relative "placeholder"
require_relative "indentation"

module Cecil
  # Provides default behavior for formatting and manipulating strings of code.
  # It handles indentation, placeholder substitution, etc.
  #
  # To define a class for your own language, subclass {Code} (which subclasses {Syntax}) and override methods of this
  # class.
  class Syntax
    # Methods defined in this module are available in a Cecil block.
    #
    # To add your own helper methods, subclass {Code}, and in your class, define a module named `Helpers`. If you want
    # your parent class' helper methods, then `include` your parent class' `Helpers` module in yours.
    module Helpers
    end

    # Returns the string to use for each level of indentation. Default is 4 spaces.
    #
    # To turn off indentation, override this method to return an empty string.
    #
    # @return [String] the string to use for each level of indentation. Default is 4 spaces.
    #
    # @example Use tab for indentation
    #    class MySyntax < Cecil::Code
    #      def indent_chars = "\t"
    #    end
    #
    # @example Use 2 spaces for indentation
    #    class MySyntax < Cecil::Code
    #      def indent_chars = "  "
    #    end
    def indent_chars = "    "

    # When indenting with a code block, the end of the code string is searched for consecutive opening brackets. Each
    # opening bracket gets closed with its matching closing bracket.
    #
    # E.g.
    #
    #     `my_func( (<`[] do
    #       `more code`
    #     end
    #     # outputs:
    #     # my_func((<
    #     #     more code
    #     # >) )
    #
    # @return [Hash{String => String}] Pairs of opening/closing strings
    #
    # @example Close `{` and `[` brackets.
    #    class MySyntax < Cecil::Code
    #      def block_ending_pairs
    #        {
    #          "{" => "}",
    #          "[" => "]",
    #
    #          " " => " ", # allows for "my_func  { [ " to be closed with " ] }  "
    #          "\t" => "\t" # allows for "my_func\t{[\t" to be closed with "\t]}\t"
    #        }
    #      end
    #    end
    #
    # @example Turn this feature off, and don't close open brackets
    #    class MySyntax < Cecil::Code
    #      def block_ending_pairs = {}
    #    end
    def block_ending_pairs
      {
        "{" => "}",
        "[" => "]",
        "<" => ">",
        "(" => ")",

        " " => " ", # allows for "my_func  ( [ " to be closed with " ] )  "
        "\t" => "\t" # allows for "my_func\t([\t" to be closed with "\t])\t"
      }
    end

    # Pairs that can be used to surround placeholder names. The pairs that are used do not change the placeholder's
    # name.
    #
    # E.g., these all produce the same result:
    #
    #     `const $field`[field: 'username']
    #     `const ${field}`[field: 'username']
    #     `const $[field]`[field: 'username']
    #     `const $<field>`[field: 'username']
    #     `const $(field)`[field: 'username']
    #
    # By default, `"" => ""` is one of the pairs, meaning you don't need to surround placeholder names.
    #
    # @return [Regexp]
    #
    # @example Allow `$/my_field/` syntax for placeholders, in addition to the default options
    #    class MySyntax < Cecil::Code
    #      def placeholder_delimiting_pairs = super.merge("/" => "/")
    #    end
    #
    # @example Turn off placeholder delimiting pairs (i.e. only allow `$my_field` syntax)
    #    class MySyntax < Cecil::Code
    #      def placeholder_delimiting_pairs = { "" => "" }
    #      # or
    #      def placeholder_delimiting_pairs = Cecil::Syntax::PLACEHOLDER_NO_BRACKETS_PAIR
    #    end
    def placeholder_delimiting_pairs
      {
        "{" => "}",
        "[" => "]",
        "<" => ">",
        "(" => ")",
        **PLACEHOLDER_NO_BRACKETS_PAIR # this needs to be last
      }
    end
    PLACEHOLDER_NO_BRACKETS_PAIR = { "" => "" }.freeze

    # Regexp to use to match a placeholder's name.
    #
    # @return [Regexp]
    #
    # @example Only allow all-caps placeholders (e.g. `$MY_FIELD`)
    #    class MySyntax < Cecil::Code
    #      def placeholder_ident_re = /[A-Z_]+/
    #    end
    #
    # @example Allow any characters placeholders, and require brackets (e.g. `${ my field ??! :) }`)
    #    class MySyntax < Cecil::Code
    #      # override `#placeholder_delimiting_pairs` to allow the default
    #      # brackets but not allow no brackets
    #      def placeholder_delimiting_pairs = super.except("")
    #
    #      # I haven't tried this... the Regexp might need to be non-greedy
    #      def placeholder_ident_re = /.+/
    #    end
    def placeholder_ident_re = /[[:alnum:]_]+/

    # Regexp to match a placeholder's starting character(s).
    #
    # @return [Regexp]
    #
    # @example Make placeholders start with `%`, e.g. `%myField`
    #    class MySyntax < Cecil::Code
    #      def placeholder_start_re = /%/
    #    end
    #
    # @example Make placeholders be all-caps without starting characters (e.g. `MY_FIELD`)
    #    class MySyntax < Cecil::Code
    #      def placeholder_start_re = //
    #    end
    def placeholder_start_re = /\$/

    # Regexp to match placeholders. By default, this constructs a Regexp from the pieces defined in:
    #
    # - {#placeholder_delimiting_pairs}
    # - {#placeholder_ident_re}
    # - {#placeholder_start_re}
    #
    # If you override this method, make sure it returns a Regexp that has a capture group named "placeholder".
    #
    # @return [Regexp] A regexp with a capture group named "placeholder"
    def placeholder_re
      /
        #{placeholder_start_re}
        #{Regexp.union(
          placeholder_delimiting_pairs.map do |pstart, pend|
            /
              #{Regexp.quote pstart}
              (?<placeholder>#{placeholder_ident_re})
              #{Regexp.quote pend}
            /x
          end
        )}
      /x
    end

    # Returns a list of {Placeholder} objects representing placeholders found in the given string. The default
    # implementation scans the string for matches of {#placeholder_re}.
    #
    # This method can be overriden to change the way placeholders are parsed, or to omit or add placeholders.
    #
    # @return [Array<Placeholder>]
    #
    # @example Palindromic names are not considered placeholders
    #    class MySyntax < Cecil::Code
    #      def scan_for_placeholders(...) = super.reject { _1.ident == _1.ident.reverse }
    #    end
    def scan_for_placeholders(src)
      Text.scan_for_re_matches(src, placeholder_re)
          .map do |match|
            Placeholder.new(match[:placeholder], *match.offset(0))
          end
    end

    # What do to in case of ambiguous indentation.
    #
    # 2 examples of ambiguous indentation:
    #
    #     `def python_fn():
    #        pass`
    #
    #     `def ruby_method
    #     end`
    #
    # Because only the second line strings have leading indentation, we don't know how the `pass` or `end` is supposed
    # to be indented because we don't know the indentation level of the first line.
    #
    # In the future we could:
    # - look at the indentation of other sibling nodes
    # - use `caller` to identify the source location of that line and read the ruby file to figure out the indentation
    #
    # For now, though, you can return:
    #
    # - {Indentation::Ambiguity.raise_error}
    # - {Indentation::Ambiguity.ignore} (works for the Ruby example)
    # - {Indentation::Ambiguity.adjust_by} (works for the Python example)
    def handle_ambiguous_indentation = Indentation::Ambiguity.raise_error
  end
end
