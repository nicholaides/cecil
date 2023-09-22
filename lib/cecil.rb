require_relative "cecil/version"

module Cecil
  class Code
    @@context = nil

    attr_accessor :depth

    def is_parent? = !!@children # rubocop:disable Naming/PredicateName
    def root? = !@src

    def initialize(src = nil)
      @src = src

      @depth = -1

      return unless @parent = @@context

      @depth = @parent.depth + 1
      @parent.add_child self
    end

    def self.src(src)
      raise "No code context running yet" unless @@context

      @@context.class.new(src)
    end

    class << self
      alias :` :src
    end

    def self.call(out = $stdout, &block)
      raise "code context already running :(" if @@context

      new
        .tap { _1.with { instance_eval(&block) } }
        .stringify
        .lstrip
        .then { out << _1 }
      out << "\n"
    end

    def self.with_context(code)
      maintain_context do
        @@context = code
        yield
      end
    end

    def self.maintain_context
      previous_context = @@context
      yield
    ensure
      @@context = previous_context
    end

    def with(*args, **options, &block)
      raise "Expects args or opts but not both" if args.any? && options.any?

      @subs = [args, options]
      @children = []

      with_context(&block) if block

      self
    end

    alias call with
    alias [] with

    def with_context(&block)
      self.class.with_context(self, &block)
    end

    def add_child(child)= @children << child

    def stringify
      srcs = [interpolate]

      if is_parent?
        srcs += @children.map(&:stringify)
        srcs << close unless root?
      end

      srcs.join
    end

    def ending_pairs
      {
        "{" => "}",
        "[" => "]",
        "<" => ">",
        "(" => ")",

        " " => " ",
        "\t" => "\t"
      }
    end

    def close
      stack = []

      src = @src.strip

      while src.size > 0 # rubocop:disable Style/ZeroLengthPredicate
        opener, closer = ending_pairs.detect { |l, _r| src.end_with?(l) } || break
        stack.push closer
        src = src[0...-opener.size]
      end

      reindent "#{stack.join.strip}\n", @depth
    end

    def <<(item)
      case item
      in Code then nil
      in String then self.class.src(item)
      end
    end

    def need_format = /\$[[:alnum:]_]+/

    def interpolate
      return unless @src

      matches = @src.to_enum(:scan, need_format).map { Regexp.last_match }.group_by { _1[0] }

      src = case @subs
            in nil
              raise "Mismatch?" if matches.any?

              @src
            in [], {}
              raise "Mismatch?" if matches.any?

              @src
            in [], opts
              raise "Mismatch?" if matches.size != opts.size

              replace(@src, matches, opts)
            in args, {}
              raise "Mismatch?" if matches.size != args.size

              replace(@src, matches, matches.keys.zip(args).to_h)
            else raise "Expects args or opts but not both: #{@subs.inspect}"
            end

      src = reindent(src, @depth)

      src += "\n" unless src.end_with?("\n")
      src
    end

    def indent_chars = "    "

    def reindent(src, depth)
      lines = src.lines
      lines.shift if lines.first == "\n"

      indented_lines =
        if lines.first =~ /^\S/
          lines.drop(1)
        else
          lines.dup
        end

      min_indent = indented_lines.grep(/\S/).map { _1.match(/^[ \t]*/)[0].size }.min || 0

      lines = lines.map { _1.sub(/^[ \t]{0,#{min_indent}}/, indent_chars * depth) }
      lines.join
    end

    def replace(src, _matches, mapping)
      mapping.reduce(src) do |str, (key, value)|
        before =
          case key
          in Symbol then "$#{key}"
          in String then key
          end

        str.gsub(before, value.to_s)
      end
    end
  end

  class TypeScript < Code
    def indent_chars = "  "

    module Helpers
      def t(items)= Array(items).join(" | ")
      def l(items)= Array(items).join(", ")
      def s(item)= item.to_s.to_json[1...-1]
      def j(item)= item.to_json
    end

    class << self
      include Helpers
    end
  end
end
