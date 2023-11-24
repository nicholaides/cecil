require_relative "cecil/version"

module Cecil
  class AbstractNode
    attr_accessor :parent, :children

    def initialize(parent:)
      self.parent = parent
    end

    def root = parent.root
    def depth = parent.depth + 1

    def add_child(child)
      self.children ||= []
      children << child
    end

    def evaluate!
      children&.map!(&:evaluate!)
      self
    end

    def stringify = children.map(&:stringify).join
  end

  class DeferredNode < AbstractNode
    def initialize(parent:, &block)
      super(parent:)
      @block = block
      add_child ContainerNode.new(parent: self)
    end

    def evaluate!
      children => [child]
      child.with(&@block)
    end

    def depth = parent.depth
  end

  class RootNode < AbstractNode
    def initialize(klass)
      super(parent: nil)

      @klass = klass
      @content_for = Hash.new { |hash, key| hash[key] = [] }
    end

    def root = self
    def depth = -1

    def with(&)
      @klass.with_node(self, &)
      self
    end

    def with_node(node, &) = @klass.with_node(node, &)

    def build_child(src:, parent: self) = @klass.new(src:, parent:)

    def content_for?(key) = @content_for.key?(key)

    def content_for__add(key, child_container) = @content_for[key] << child_container

    def content_for__place(key, new_parent)
      @content_for.fetch(key).each { _1.place_content new_parent }
    end
  end

  class ContainerNode < AbstractNode
    def with(&)
      root.with_node(self, &)
      self
    end

    def build_child(src:) = root.build_child(src:, parent: self)

    def depth = parent.depth
  end

  class ContentForNode < ContainerNode
    attr_accessor :location_parent

    def place_content(new_parent)
      self.location_parent = new_parent
      new_parent.add_child self
    end

    def depth = location_parent.depth
  end

  class Code < AbstractNode
    def initialize(src:, parent:)
      super(parent:)

      @src = src

      @placeholders = src
                      .to_enum(:scan, placeholder_re)
                      .map { Regexp.last_match }
                      .map { Cecil::Code::Placeholder.new(_1) }
    end

    def build_child(src:) = root.build_child(src:, parent: self)

    class << self
      @@nodes = []
      def current_node = @@nodes.last || raise("No code node running yet")
      def current_root = current_node.root

      def with_node(code)
        @@nodes.push code
        yield
      ensure
        @@nodes.pop
      end

      def src(src) = add_node current_node.build_child(src:)
      alias :` :src

      def defer(&) = add_node DeferredNode.new(parent: current_node, &)

      def add_node(child)
        current_node.add_child child
        child
      end

      def content_for(key, &content_block)
        if content_block
          current_root.content_for__add key, ContentForNode.new(parent: current_node).with(&content_block)
        elsif content_for?(key)
          content_for!(key)
        else
          current_node.add_child DeferredNode.new(parent: current_node) { content_for!(key) }
        end
      end

      def content_for?(key) = current_root.content_for?(key)
      def content_for!(key) = current_root.content_for__place key, current_node

      def call(out = $DEFAULT_OUTPUT, &)
        RootNode.new(self)
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

      self.children = []

      if @placeholders.any?
        @src = Cecil.interpolate(@src, @placeholders, args, options)
        @replaced = true
      end

      self.class.with_node(self, &block) if block

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
