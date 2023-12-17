require_relative "text"

module Cecil
  class Syntax
    # Returns the string to use for each level of indentation.
    #
    # Default indentation is 4 spaces.
    #
    # To turn off this feature, override this method to return an empty string.
    def indent_chars = "    "

    # When indenting with a code block, the end of the code string is searched
    # for consecutive opening brackets. Each opening bracket gets closed
    # with its matching closing bracket.
    #
    # E.g.
    # - `my_func([` is closed with "])"
    # - `my_func( [ ` is closed with " ] )"
    #
    # To turn off this feature, override this method to return an empty hash.
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

    # Pairs that can be used to surround placeholder names. The pairs that are
    # used do not change the placeholder's name.
    #
    # E.g., these all produce the same result:
    # - `\`const $field\`[field: 'username']`
    # - `\`const ${field}\`[field: 'username']`
    # - `\`const $[field]\`[field: 'username']`
    # - `\`const $<field>\`[field: 'username']`
    # - `\`const $(field)\`[field: 'username']`
    #
    # By default, `"" => ""` is one of the pairs, meaning you don't need to
    # surround placeholder names.
    #
    # To turn off this feature (i.e. don't allow brackets around placeholder
    # names), override this method to return `{ "" => "" }`
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

    # Regexp to match a placeholder's name.
    #
    # To allow any string as a placeholder name, you'd want to
    # - override `#placeholder_delimiting_pairs` to return `PLACEHOLDER_NO_BRACKETS_PAIR`
    # - override this method to return /.*/ (I haven't tried this... the Regexp
    # might need to be non-greedy)
    def placeholder_ident_re = /[[:alnum:]_]+/

    # Regexp to match a placeholder's starting character(s).
    #
    # To use no starting characters, override this method to retun an empty
    # Regexp, i.e. `//`
    def placeholder_start_re = /\$/

    # Regexp to match placeholders. By default, this constructs a Regexp from
    # the pieces defined in:
    # - `#placeholder_delimiting_pairs`
    # - `#placeholder_ident_re`
    # - `#placeholder_start_re`
    #
    # If you override this method, make sure it returns a Regexp that has a
    # capture group named "placeholder".
    def placeholder_re
      /
        #{placeholder_start_re}
        #{Regexp.union(
          placeholder_delimiting_pairs.map do |pstart, pend|
            /
              #{Regexp.quote pstart}
              (?<placeholder>
                #{placeholder_ident_re}
              )
              #{Regexp.quote pend}
            /x
          end
        )}
      /x
    end

    # Returns a list of `Placeholder` objects representing placeholders found in
    # the given string. The default implementation scans the string for matches
    # of `#placeholder_re`. This method can be overriden to change the way
    # placeholders are parsed, or to omit or add placeholders.
    def scan_for_placeholders(src)
      Text.scan_for_re_matches(src, placeholder_re)
          .map do |match|
            Cecil::Placeholder.new(match[:placeholder], *match.offset(0))
          end
    end
  end
end
