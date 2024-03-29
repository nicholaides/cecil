module Cecil
  module Indentation # rubocop:disable Style/Documentation
    module_function

    # @!visibility private
    def line_level(str) = str.index(/[^\t ]/) || str.length

    # @!visibility private
    def levels(lines) = lines.map { line_level(_1) }

    # @!visibility private
    def level__basic(src) = levels(src.lines.grep(/\S/)).min

    module Ambiguity # rubocop:disable Style/Documentation
      module_function

      # When given an ambiguously indented string, it assumes that first line is `adjustment` characters less than the
      # least indented of the other lines.
      #
      # Useful for this situation. Setting to `adjust_by(4)` will behave
      # according to what's intended.
      #
      #     `def python_fn():
      #         pass`
      def adjust_by(adjustment) = ->(min_level:, **) { min_level - adjustment }

      # When given an ambiguously indented string, assume that first line is the same as the least indented of the other
      # lines.
      #
      # Useful for this situation:
      #
      #     `def ruby_method
      #      end`
      def ignore = adjust_by(0)

      # When given an ambiguously indented string, raise an exception
      def raise_error
        lambda do |src:, **|
          raise <<~MSG
            Indentation is ambiguous, cannot reindent. Try adding a blank
            line at the beginning or end of this fragment. Fragment:

            #{src}
          MSG
        end
      end
    end

    # @!visibility private
    def level__starts_and_stops_with_content(src, handle_ambiguity:)
      levels = levels(src.lines.drop(1).grep(/\S/))

      min_level = levels.min

      if levels.last == levels.max && (ambiguous_level = handle_ambiguity.call(src:, min_level:))
        return ambiguous_level
      end

      min_level
    end

    # @!visibility private
    def level__starts_with_content(src)
      src.lines => _first, *middle, last

      levels([*middle.grep(/\S/), last]).min
    end

    # @!visibility private
    SINGLE_LINE = /\A.*\n?\z/

    # @!visibility private
    STARTS_WITH_CONTENT = /\A\S/ # e.g. `content ...

    # @!visibility private
    ENDS_WITH_CONTENT = /.*\S.*\z/ # e.g. "..\n content "

    # @!visibility private
    def level(src, handle_ambiguity:)
      case src
      when SINGLE_LINE
        0
      when STARTS_WITH_CONTENT
        if src =~ ENDS_WITH_CONTENT
          level__starts_and_stops_with_content(src, handle_ambiguity:)
        else
          level__starts_with_content(src)
        end
      else
        level__basic(src)
      end
    end

    # Reindent `src` string to the level specified by `depth`. `indent_chars` is used only the current level of
    # indentation as well as add more indentation.
    #
    # Reindents the given source code string to the specified depth.
    #
    # @param src [String] The source code to reindent
    # @param depth [Integer] The indentation level to reindent to
    # @param indent_chars [String] The indentation characters to use
    # @param handle_ambiguity [Proc] How to handle ambiguous indentation cases.
    #
    #   - defaults to {Ambiguity.raise_error}
    #   - use {Ambiguity.ignore} if your syntax doesn't have signigicant whitespace
    #   - use {Ambiguity.adjust_by} if your syntax has significant whitespace
    def reindent(src, depth, indent_chars, handle_ambiguity: Ambiguity.raise_error)
      # Turn
      # "\n" +
      # "  line 1\n" +
      # "    line 2\n"
      # into
      # "  line 1\n" +
      # "    line 2\n"
      src = src.sub(/\A\R/m, "")

      new_indentation = indent_chars * depth
      reindent_line_re = /^[ \t]{0,#{level(src, handle_ambiguity:)}}/

      lines = src.lines.map do |line|
        if line =~ /\S/
          line.sub(reindent_line_re, new_indentation)
        else
          line.sub(/^[ \t]*/, "")
        end
      end

      lines.join
    end
  end
end
