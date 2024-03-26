require_relative "placeholder"
require_relative "indentation"

module Cecil
  # {Code} serves as the base class for generating source code using Cecil.
  # Subclassing {Code} allows customizing the behavior (indentation, auto-closing brackets, etc) and providing helpers.
  #
  # - Override {Code} instance methods to change behavior.
  # - Defined a module named `Helpers` in your subclass to add methods available in the Cecil block.
  #
  # Check out classes in the {Lang} module for examples of customizing {Code}.
  #
  # @example Creating a custom syntax
  #   class CSS < Cecil::Code
  #     # Override instance methods to customize behavior
  #
  #     def indent_chars = "  " # use 2 spaces for indentation
  #
  #     # methods in this module will be available in a Cecil block
  #     module Helpers
  #
  #       # if we want to inherit other helpers, include the module
  #       include Cecil::Code::Helpers
  #
  #       def data_uri(file) = DataURI.from_file(file) # fake code
  #     end
  #   end
  #
  #   background_types = {
  #     star: "star-@100x100.png",
  #     dots: "polka-dots@50x50.png",
  #   }
  #
  #   CSS.generate_string do
  #     background_types.each do |bg_name, image_file|
  #       `.bg-$class {`[bg_name] do
  #
  #         # #data_uri is available because it was defined in CSS::Helpers
  #         `background-image: url($img);`[data_uri(image_file)]
  #       end
  #     end
  #   end
  #
  #   # outputs:
  #   # .bg-star {
  #   #   background-image: url(data:image/png;base64,iRxVB0…);
  #   # }
  #   # .bg-dots {
  #   #   background-image: url(data:image/png;base64,iRxVB0…);
  #   # }
  class Code
    class << self
      # Generates output by executing the given block and writing its return value to the provided output buffer/stream.
      #
      # The stream is written to by calling `#<<` with the generated source code.
      #
      # @param [#<<] out The output buffer/stream to write to
      # @yield The given block can use backticks (i.e. {BlockContext#src `` #`(code_str) ``} ) to add lines of code to
      #   the buffer/stream.
      # @return The returned value of `out <<`
      #
      # @example Outputing to stdout
      #   Cecil.generate do
      #     `function helloWorld() {}`
      #   end
      #
      # @example Outputing to a file
      #   File.open "output.js", "w" do |file|
      #     Cecil.generate file do
      #       `function helloWorld() {}`
      #     end
      #   end
      def generate(out = $stdout, &) = Cecil.generate(syntax_class: self, out:, &)

      # Generates output and returns it as a string
      #
      # @yield (see .generate)
      # @return [String] The generated source code
      # @see .generate
      # @example
      #   my_code = Cecil.generate_string do
      #     `function helloWorld() {}`
      #   end
      #   puts my_code
      def generate_string(&) = generate("", &)
    end

    # Subclasses of {Code} can define a module named `Helpers` and add methods to it that will be available inside a
    # Cecil block for that subclass.
    #
    # When defining your own `Helpers` module, if you want your parent class' helper methods, then `include` your parent
    # class' `Helpers` module in yours, like this:
    #
    #     class CSS < Code::Syntax
    #       module Helpers
    #         include Code::Syntax::Helpers
    #
    #         def data_uri(file) = DataURI.from_file(file) # this is made up, not working code
    #
    #       end
    #     end
    #
    #     class SCSS < CSS
    #       module Helpers
    #         include CSS::Helpers # now `data_uri` will be an available helper
    #       end
    #     end
    #
    # Subclasses that don't define a `Helpers` module inherit the one from their parent class.
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

    # When indenting with a code block, the end of the code string is searched for consecutive opening brackets, each of
    # which gets closed with a matching closing bracket.
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
    # @example Override to close only `{` and `[` brackets.
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
    # @example Override to also close `/*` with `*/`
    #    class MySyntax < Cecil::Code
    #      def block_ending_pairs = super.merge({ '/*' => '*/' })
    #    end
    #
    # @example Override to turn this feature off, and don't close open brackets
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
    # @example Override to allow `$/my_field/` syntax for placeholders, in addition to the default options
    #    class MySyntax < Cecil::Code
    #      def placeholder_delimiting_pairs = super.merge("/" => "/")
    #    end
    #
    # @example Override to turn off placeholder delimiting pairs (i.e. only allow `$my_field` syntax)
    #    class MySyntax < Cecil::Code
    #      def placeholder_delimiting_pairs = { "" => "" }
    #      # or
    #      def placeholder_delimiting_pairs = Cecil::Code::PLACEHOLDER_NO_BRACKETS_PAIR
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
    # @example Override to only allow all-caps placeholders (e.g. `$MY_FIELD`)
    #    class MySyntax < Cecil::Code
    #      def placeholder_ident_re = /[A-Z_]+/
    #    end
    #
    # @example Override to allow any characters placeholders, and require brackets (e.g. `${ my field ??! :) }`)
    #    class MySyntax < Cecil::Code
    #      # override `#placeholder_delimiting_pairs` to allow the default
    #      # brackets but not allow no brackets
    #      def placeholder_delimiting_pairs = super.except("")
    #      def placeholder_ident_re = /.+/
    #    end
    def placeholder_ident_re = /[[:alnum:]_]+/

    # Regexp to match a placeholder's starting character(s).
    #
    # @return [Regexp]
    #
    # @example Override to make placeholders start with `%`, e.g. `%myField`
    #    class MySyntax < Cecil::Code
    #      def placeholder_start_re = /%/
    #    end
    #
    # @example Override to make placeholders be all-caps without starting characters (e.g. `MY_FIELD`)
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
    # This method can be overriden to change the way placeholders are parsed, or to omit, add, or modify placeholders.
    #
    # @return [Array<Placeholder>]
    #
    # @example Override to transform placeholder names to lowercase
    #    class MySyntax < Cecil::Code
    #      super.map do |placeholder|
    #        placeholder.transform_key(:ident, &:downcase)
    #      end
    #    end
    #
    #    MySyntax.generate_string do
    #      `const $VAR = $VALUE`[var: 'id', value: '42']
    #    end
    #    # outputs:
    #    # const id = 42
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
    # Because only the second line strings have leading indentation, we don't know how `pass` or `end` should be
    # indented.
    #
    # In the future we could use `caller` to identify the source location of that line and read the ruby file to figure
    # out the indentation.
    #
    # For now, though, you can return:
    #
    # - {Indentation::Ambiguity.raise_error}
    # - {Indentation::Ambiguity.ignore} (works for the Ruby example)
    # - {Indentation::Ambiguity.adjust_by} (works for the Python example)
    #
    # @example Override to ignore ambiguous indentation
    #   class MyRubySyntax < Cecil::Code
    #     def handle_ambiguous_indentation = Indentation::Ambiguity.ignore
    #   end
    #
    # @example Override to adjust indentation
    #   class MyRubySyntax < Cecil::Code
    #     def handle_ambiguous_indentation
    #       Indentation::Ambiguity.adjust_by(2)
    #     end
    #   end
    def handle_ambiguous_indentation = Indentation::Ambiguity.raise_error
  end
end
