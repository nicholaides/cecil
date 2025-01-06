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

    # Interpolate positional placeholder values into a string
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param values [Array<#to_s>]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def interpolate_positional(template, placeholders, values)
      match_idents = placeholders.to_set(&:ident)

      if match_idents.size != values.size
        raise "Mismatch between number of placeholders (#{match_idents.size}) and given values (#{values.size})"
      end

      replace(template, placeholders, match_idents.zip(values).to_h)
    end

    # Interpolate named placeholder values into a string
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param idents_to_values [Hash{#to_s=>#to_s}]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def interpolate_named(template, placeholders, idents_to_values)
      duplicated_keys = idents_to_values.keys.group_by(&:to_s).values.select { _1.size > 1 }
      if duplicated_keys.any?
        keys_list = duplicated_keys.map { "\n - #{_1.map(&:inspect).join(", ")}\n" }.join
        raise "Duplicate placeholder value keys:#{keys_list}"
      end

      values_idents = idents_to_values.keys.to_set(&:to_s)
      match_idents = placeholders.to_set(&:ident)

      if match_idents != values_idents
        missing_values = match_idents - values_idents
        extra_values = values_idents - match_idents
        message = "Mismatch between placeholders and provide values."
        message << "\n Missing values for placeholders #{missing_values.join(", ")}" if missing_values.any?
        message << "\n Missing placeholders for values #{extra_values.join(", ")}" if extra_values.any?

        raise message
      end

      replace(template, placeholders, idents_to_values)
    end

    # Replace placeholders in the string with provided values
    #
    # @param template [String]
    # @param placeholders [Array<Placeholder>]
    # @param idents_to_values [Hash{#to_s=>#to_s}]
    # @return [String] `template`, except with placeholders replaced with
    #   provided values
    def replace(template, placeholders, idents_to_values)
      values = idents_to_values.transform_keys(&:to_s)

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

      block_ending_pairs.find { |opener, _closer| src.end_with?(opener) }
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
