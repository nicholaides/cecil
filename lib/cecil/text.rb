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

    def intentation_level(str) = str.index(/[^\t ]/) || str.length

    # Reindent `src` string to the level specified by `depth`. `indent_chars` is
    # used only the current level of indentation as well as add more
    # indentation.
    #
    # @param src [String]
    # @param depth [Integer]
    # @param indent_chars [String]
    def reindent(src, depth, indent_chars)
      lines = src.lines

      # e.g. this situation:
      # `
      #   my content
      #   ...
      lines.shift if lines.first in "\n" | "\r\n"

      indented_lines =
        if lines.size == 1
          []
        elsif lines.first =~ /^\S/ # e.g. `content...
          not_first_lines = lines.drop(1)
          last_line_of_multi_starting_with_content = not_first_lines.last

          [*not_first_lines.grep(/\S/), *last_line_of_multi_starting_with_content]
        else # e.g. `  content...
          lines.grep(/\S/)
        end

      indentation_levels = indented_lines.map { intentation_level(_1) }

      min_indent = indentation_levels.min || 0
      max_indent = indentation_levels.max || 0

      last_line = last_line_of_multi_starting_with_content
      raise "Ambiguous, cannot reindent:\n#{src}" if last_line =~ /\S/ && intentation_level(last_line) == max_indent

      new_indentation = indent_chars * depth
      reindent_line_re = /^[ \t]{0,#{min_indent}}/

      lines = lines.map do |line|
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
