module Cecil
  module Indentation
    module_function

    def line_level(str) = str.index(/[^\t ]/) || str.length

    def levels(lines) = lines.map { line_level(_1) }

    def level__basic(src) = levels(src.lines.grep(/\S/)).min

    def adjust_ambigious_indentation(adjumstment) = ->(min_level:, **) { min_level - adjumstment }
    def ignore_ambiguous_indentation = adjust_ambigious_indentation(0)

    RAISE_ON_AMBIGUOUS_INDENTATION = ->(src:, **) { raise "Ambiguous, cannot reindent:\n#{src}" }

    def level__starts_and_stops_with_content(src, handle_ambiguity:)
      levels = levels(src.lines.drop(1).grep(/\S/))

      min_level = levels.min

      if levels.last == levels.max && ambiguous_level = handle_ambiguity.call(src:, min_level:)
        return ambiguous_level
      end

      min_level
    end

    def level__starts_with_content(src)
      src.lines => _first, *middle, last

      levels([*middle.grep(/\S/), last]).min
    end

    SINGLE_LINE = /\A.*\n?\z/
    STARTS_WITH_CONTENT = /\A\S/ # e.g. `content ...
    ENDS_WITH_CONTENT = /.*\S.*\z/ # e.g. "..\n content "

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

    # Reindent `src` string to the level specified by `depth`. `indent_chars` is
    # used only the current level of indentation as well as add more
    # indentation.
    #
    # @param src [String]
    # @param depth [Integer]
    # @param indent_chars [String]
    def reindent(src, depth, indent_chars, handle_ambiguity: RAISE_ON_AMBIGUOUS_INDENTATION)
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
