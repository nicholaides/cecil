require_relative "cecil/version"
require_relative "cecil/nodes"
require_relative "cecil/content_for"
require_relative "cecil/builder"

require "forwardable"

module Cecil
  class Configuration
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

  class Code < Configuration
    def self.call(out = $DEFAULT_OUTPUT, &)
      config = new
      builder = Builder.new(config)
      BlockContext.new(builder, config.helpers).instance_exec(&)
      builder
        .root
        .evaluate!
        .stringify(config)
        .lstrip
        .then { out << _1 }
    end

    def self.generate_string(&) = call("", &)
  end

  # TODO: test that it can access methods (and therefore should not inherit from BasicObject)
  # TODO: test that helpers works
  class BlockContext
    def initialize(builder, helpers)
      @builder = builder
      extend helpers
    end

    def src(...) = @builder.src(...)
    alias :` :src

    def defer(...) = @builder.defer(...)

    def content_for(...) = @builder.content_for(...)
    def content_for?(...) = @builder.content_for?(...)
    def content_for!(...) = @builder.content_for!(...)
  end
end
