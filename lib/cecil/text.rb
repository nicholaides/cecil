module Cecil
  # Represents the name and location of a placeholder in a string.
  Placeholder = Struct.new(:ident, :offset_start, :offset_end) do
    # @!attribute ident
    #   @return [String] the name of this placeholder. E.g. the `ident` of `${my_field}` would be `my_field`

    # @!attribute offset_start
    #   @return [Integer] the offset where this placeholder starts in the
    #     string. This number is usually taken from a Regexp match.

    # @!attribute offset_end
    #   @return [Integer] the offset where this placeholder ends in the
    #     string. This number is usually taken from a Regexp match.

    # Return the range that this placeholder occupies in the string
    # @return [Range(Integer)]
    def range = offset_start...offset_end
  end

  # Helper methods for string searching, manipulating, etc.
  module Text
    module_function

    # Scan a string for matches on a Regexp and return each MatchObject
    #
    # @param src [String] the string to scan
    # @param regexp [Regexp] the regexp to scan with
    # @return [Array<MatchData>] The MatchData objects for each instance of the regexp matched in the string
    def scan_for_re_matches(src, regexp) = src.to_enum(:scan, regexp).map { Regexp.last_match }

    # Reindent `src` string to the level specified by `depth`. `indent_chars` is
    # used to determine the current level of indentation as well as add more
    # indentation.
    #
    # @param src [String]
    # @param depth [Integer]
    # @param indent_chars [String]
    def reindent(src, depth, indent_chars)
      lines = src.lines
      lines.shift if lines.first == "\n"

      indented_lines =
        if lines.first =~ /^\S/
          lines.drop(1)
        else
          lines.dup
        end

      min_indent = indented_lines
                   .grep(/\S/)
                   .map { _1.match(/^[ \t]*/)[0].size }
                   .min || 0

      lines = lines.map { _1.sub(/^[ \t]{0,#{min_indent}}/, indent_chars * depth) }
      lines.join
    end

    # Interpolate positional placeholder values into a string
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param options [Array<#to_s>]
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
