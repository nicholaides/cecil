module Cecil
  # Helper methods for string searching, manipulating, etc.
  module Text
    module_function

    # Scan a string for matches on a Regexp and return each MatchObject
    #
    # @param str [String] the string to scan
    # @param regexp [Regexp] the regexp to scan with
    # @return [Array<MatchData>] The MatchData objects for each instance of the regexp matched in the string
    def scan_for_re_matches(str, regexp) = str.to_enum(:scan, regexp).map { Regexp.last_match }

    def intentation_level_of_line(str) = str.index(/[^\t ]/) || str.length

    def indent_levels(lines) = lines.map { intentation_level_of_line(_1) }

    def indentation_basic(src) = indent_levels(src.lines.grep(/\S/)).min

    def indentation_when_starts_and_stops_with_content(src)
      levels = indent_levels(src.lines.drop(1).grep(/\S/))

      raise "Ambiguous, cannot reindent:\n#{src}" if levels.last == levels.max

      levels.min
    end

    def indentation_when_starts_with_content(src)
      src.lines => _first, *middle, last

      indent_levels([*middle.grep(/\S/), last]).min
    end

    SINGLE_LINE = /\A.*\n?\z/
    STARTS_WITH_CONTENT = /\A\S/ # e.g. `content ...
    ENDS_WITH_CONTENT = /.*\S.*\n?\z/
    def indentation_level(src)
      case src
      when SINGLE_LINE # single line
        0
      when STARTS_WITH_CONTENT
        if src =~ ENDS_WITH_CONTENT
          indentation_when_starts_and_stops_with_content(src)
        else
          indentation_when_starts_with_content(src)
        end
      else
        indentation_basic(src)
      end
    end

    # Reindent `src` string to the level specified by `depth`. `indent_chars` is
    # used only the current level of indentation as well as add more
    # indentation.
    #
    # @param src [String]
    # @param depth [Integer]
    # @param indent_chars [String]
    def reindent(src, depth, indent_chars)
      # Turn
      # "\n" +
      # "  line 1\n" +
      # "    line 2\n"
      # into
      # "  line 1\n" +
      # "    line 2\n"
      src = src.sub(/\A\R/m, "")

      new_indentation = indent_chars * depth
      reindent_line_re = /^[ \t]{0,#{indentation_level(src)}}/

      lines = src.lines.map do |line|
        if line =~ /\S/
          line.sub(reindent_line_re, new_indentation)
        else
          line.sub(/^[ \t]*/, "")
        end
      end

      lines.join
    end

    # Interpolate positional placeholder values into a string
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param args [Array<#to_s>]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def interpolate_positional(template, placeholders, args)
      match_idents = placeholders.to_set(&:ident)

      if match_idents.size != args.size
        raise "Mismatch between number of placeholders (#{placeholders.size}) and given values (#{args.size})"
      end

      replace(template, placeholders, match_idents.zip(args).to_h)
    end

    # Interpolate named placeholder values into a string
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param options [Hash{#to_s=>#to_s}]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def interpolate_named(template, placeholders, options)
      values_idents = options.keys.to_set(&:to_s)
      match_idents = placeholders.to_set(&:ident)

      if match_idents != values_idents
        missing_values = match_idents - values_idents
        extra_values = values_idents - match_idents
        message = "Mismatch between placeholders and provide values."
        message << "\n Missing values for placeholders #{missing_values.join(", ")}" if missing_values.any?
        message << "\n Missing placeholders for values #{extra_values.join(", ")}" if extra_values.any?

        raise message
      end

      replace(template, placeholders, options)
    end

    # Replace placeholders in the string with provided values
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param placeholder_inputs [Hash{#to_s=>#to_s}]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def replace(template, placeholders, placeholder_inputs)
      values = placeholder_inputs.transform_keys(&:to_s)

      template.dup.tap do |new_src|
        placeholders.reverse.each do |placeholder|
          value = values.fetch(placeholder.ident)

          new_src[placeholder.range] = value.to_s
        end
      end
    end

    # Returns any closing bracket found
    #
    # @param src [String]
    # @param block_ending_pairs [Hash{String=>String}]
    def match_ending_pair(src, block_ending_pairs)
      return if src.empty?

      block_ending_pairs.detect { |opener, _closer| src.end_with?(opener) }
    end

    # Returns or yields each closing bracket.
    #
    # @param src [String]
    # @param block_ending_pairs [Hash{String=>String}]
    #
    # @overload closers(src, block_ending_pairs, &)
    #   With block given, behaves like {.each_closer}
    #   @yield [String]
    #
    # @overload closers(src, block_ending_pairs)
    #   When no block is given, returns an enumerator of the {.each_closer} method
    #   @return [Enumerator<String>]
    def closers(src, block_ending_pairs)
      return enum_for(:closers, src, block_ending_pairs) unless block_given?

      while match_ending_pair(src, block_ending_pairs) in [opener, closer]
        yield closer
        src = src[0...-opener.size]
      end
    end
  end
end
