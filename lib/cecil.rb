require_relative "cecil/version"

module Cecil
  class DeferredCode
    def initialize(parent:, &block)
      @block = block
      @parent = parent

      @child = @parent.class.new(src: nil, parent: self)
      @parent.add_child self
    end

    def depth = @parent.depth

    def add_child(...) = nil

    def evaluate!
      @child.with(&@block)
    end
  end

  class Code
    attr_accessor :depth

    def is_parent? = !!@children # rubocop:disable Naming/PredicateName
    def root? = !@src

    def initialize(src: nil, parent: nil)
      @src = src
      @parent = parent
      @depth = -1

      @placeholders = Array(
        src && src.to_enum(:scan, placeholder_re)
           .map { Regexp.last_match }
           .map { Cecil::Code::Placeholder.new(_1) }
      )

      return unless @parent

      @depth = @parent.depth + 1
      @parent.add_child self
    end

    def evaluate!
      @children&.map!(&:evaluate!)
      self
    end

    class << self
      def current_context = @@contexts.last
      @@contexts = []

      def with_context(code)
        @@contexts.push code
        yield
      ensure
        @@contexts.pop
      end

      def src(src, &deferred)
        raise "No code context running yet" unless current_context

        if deferred
          DeferredCode.new(parent: current_context, &deferred)
        else
          current_context.class.new(src:, parent: current_context)
        end
      end
      alias :` :src

      def defer(&)
        src(nil, &)
      end

      def call(out = $DEFAULT_OUTPUT, &)
        new
          .tap { _1.with { instance_eval(&) } }
          .evaluate!
          .stringify
          .lstrip
          .then { out << _1 }
      end

      def generate_string(&)
        call("", &)
      end
    end

    def with(*args, **options, &block)
      raise "Expects args or opts but not both" if args.any? && options.any?

      @subs = [args, options]

      if @placeholders.any?
        @src = Cecil.interpolate(@src, @placeholders, args, options)
        @replaced = true
      end

      @children = []

      self.class.with_context(self, &block) if block

      self
    end

    alias call with
    alias [] with

    def add_child(child) = @children << child

    def stringify
      raise "Mismatch?" if @placeholders.any? && !@replaced

      srcs = [reformat]

      if is_parent?
        srcs += @children.map(&:stringify)
        srcs << close unless root?
      end

      srcs.join
    end

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

    def close
      stack = []

      src = @src.strip

      while src.size > 0 # rubocop:disable Style/ZeroLengthPredicate
        opener, closer = block_ending_pairs.detect { |l, _r| src.end_with?(l) } || break
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

    class Placeholder
      attr_reader :ident, :offset_start, :offset_end

      def initialize(match)
        @ident = match[:placeholder]
        @offset_start, @offset_end = match.offset(0)
      end

      def range = offset_start...offset_end
    end

    def reformat
      return unless @src

      src = reindent(@src, @depth)

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
  end

  require "json"
  class TypeScript < Code
    def indent_chars = "  "

    module Helpers
      def t(items) = Array(items).join(" | ")
      def l(items) = Array(items).join(", ")
      def s(item) = item.to_s.to_json[1...-1]
      def j(item) = item.to_json
    end

    class << self
      include Helpers
    end
  end

  def self.interpolate(template, placeholders, args, options)
    return unless template

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
    else raise "Expects args or opts but not both: #{subs.inspect}"
    end
  end

  def self.replace(src, placeholders, placeholder_inputs)
    values = placeholder_inputs.transform_keys(&:to_s)

    src.dup.tap do |new_src|
      placeholders.reverse.each do |placeholder|
        value = values.fetch(placeholder.ident)

        new_src[placeholder.range] = value.to_s
      end
    end
  end
end
