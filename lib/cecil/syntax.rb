module Cecil
  class Syntax
    class << self
      def helpers(&)
        @helpers = Module.new(&) if block_given?
        @helpers ||= Module.new
        @helpers
      end
    end

    def helpers = self.class.helpers

    def block_ending_pairs
      {
        "{" => "}",
        "[" => "]",
        "<" => ">",
        "(" => ")",

        " " => " ",
        "\t" => "\t"
      }
    end

    def placeholder_delimiting_pairs
      {
        "{" => "}",
        "[" => "]",
        "<" => ">",
        "(" => ")",
        "" => ""
      }
    end

    def indent_chars = "    "

    def placeholder_ident_re = /[[:alnum:]_]+/

    def placeholder_start = /\$/

    def placeholder_re
      /
        #{placeholder_start}
        #{
          Regexp.union(
            placeholder_delimiting_pairs.map do |pstart, pend|
              /
                #{Regexp.quote pstart}
                (?<placeholder>
                  #{placeholder_ident_re}
                )
                #{Regexp.quote pend}
              /x
            end
          )
        }
      /x
    end
  end
end
