module Cecil
  # Represents the name and location of a placeholder in a string.
  Placeholder = Struct.new(:ident, :offset_start, :offset_end) do
    def range = offset_start...offset_end
  end

  module Text
    module_function

    # Scan a string and return the match objects
    def scan_for_re_matches(src, regexp) = src.to_enum(:scan, regexp).map { Regexp.last_match }

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

    def interpolate(template, placeholders, args, options)
      match_idents = placeholders.to_set(&:ident)

      subs = [args, options]

      case subs
      in [], {}
        raise "Mismatch?" if placeholders.any?

        template
      in [], opts
        raise "Mismatch?" if match_idents != opts.keys.to_set(&:to_s)

        replace(template, placeholders, opts)
      in args, {}
        raise "Mismatch?" if match_idents.size != args.size

        replace(template, placeholders, match_idents.zip(args).to_h)
      else
        raise "Expects args or opts but not both: #{subs.inspect}"
      end
    end

    def replace(src, placeholders, placeholder_inputs)
      values = placeholder_inputs.transform_keys(&:to_s)

      src.dup.tap do |new_src|
        placeholders.reverse.each do |placeholder|
          value = values.fetch(placeholder.ident)

          new_src[placeholder.range] = value.to_s
        end
      end
    end

    def each_closer(src, block_ending_pairs)
      while !src.empty? && match = block_ending_pairs.detect { |l, _r| src.end_with?(l) }
        match => [opener, closer]
        yield closer
        src = src[0...-opener.size]
      end
    end

    def closers(...) = block_given? ? each_closer(...) : enum_for(:each_closer, ...) # rubocop:disable Lint/ToEnumArguments
  end
end
