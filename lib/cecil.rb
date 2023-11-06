require_relative "cecil/version"

module Cecil
  module ChildNode
    def parent = @parent

    def parent=(parent)
      @parent = parent
    end

    def root = parent.root
    def depth = parent.depth + 1
  end

  module ParentNode
    attr_reader :children

    def init_children = @children = []
    def add_child(child) = @children << child

    def evaluate!
      children&.map!(&:evaluate!)
      self
    end

    def stringify = children.map(&:stringify).join
  end

  class Deferred
    include ChildNode

    def initialize(parent:, &block)
      @block = block
      @parent = parent
      @child = CodeContainer.new(parent: self)
    end

    def evaluate! = @child.with(&@block)
  end

  class Root
    include ParentNode

    def root = self
    def depth = -1

    def initialize(klass)
      @klass = klass
      init_children
    end

    def with(&)
      @klass.with_context(self, &)
      self
    end

    def with_context(context, &)
      @klass.with_context(context, &)
    end

    def build_child(src:, parent: self) = @klass.new(src:, parent:)
  end

  class CodeContainer
    include ChildNode
    include ParentNode

    def initialize(parent:)
      @parent = parent
      init_children
    end

    def with(&)
      root.with_context(self, &)
      self
    end

    def build_child(src:) = root.build_child(src:, parent: self)
  end

  class Code
    include ChildNode
    include ParentNode

    def root = @parent.root

    def initialize(src:, parent:)
      @src = src
      @parent = parent

      @placeholders = src
                      .to_enum(:scan, placeholder_re)
                      .map { Regexp.last_match }
                      .map { Cecil::Code::Placeholder.new(_1) }
    end

    def build_child(src:) = root.build_child(src:, parent: self)

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

        child = if deferred
                  Deferred.new(parent: current_context, &deferred)
                else
                  current_context.build_child(src:)
                end
        current_context.add_child child
        child
      end
      alias :` :src

      def defer(&)
        src(nil, &)
      end

      def call(out = $DEFAULT_OUTPUT, &)
        Root.new(self)
            .tap { _1.with { instance_eval(&) } }
            .evaluate!
            .stringify
            .lstrip
            .then { out << _1 }
      end

      def generate_string(&) = call("", &)
    end

    def with(*args, **options, &block)
      raise "Expects args or opts but not both" if args.any? && options.any?

      init_children

      if @placeholders.any?
        @src = Cecil.interpolate(@src, @placeholders, args, options)
        @replaced = true
      end

      self.class.with_context(self, &block) if block

      self
    end

    alias call with
    alias [] with

    def stringify
      raise "Mismatch?" if @placeholders.any? && !@replaced

      srcs = [reformat]

      if children
        srcs += children.map(&:stringify)
        srcs << close
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

      reindent "#{stack.join.strip}\n", depth
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
      src = reindent(@src, depth)

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
