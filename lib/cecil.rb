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
      child
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

    def child
      children => [container]
      container
    end

    def evaluate! = child.with(&@block)

    def depth = parent.depth
  end

  class RootNode < AbstractNode
    def initialize(builder)
      super(parent: nil)

      @builder = builder
      @content_for = Hash.new { |hash, key| hash[key] = [] }
    end

    def root = self
    def depth = -1

    def with(&)
      @builder.with_node(self, &)
      self
    end

    def with_node(...) = @builder.with_node(...)
    def src(...) = @builder.src(...)

    def build_child(src:, parent: self) = CodeNode.new(src:, parent:)

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

  module Builder
    class Generic
      attr_accessor :root

      def initialize
        @root = RootNode.new(self)
        @nodes = [@root]
      end

      def current_node = @nodes.last || raise("No code node running yet")

      def with_node(code)
        @nodes.push code
        yield
      ensure
        @nodes.pop
      end

      # dx/block
      def src(src) = add_node current_node.build_child(src:)

      # dx/block
      def defer(&) = add_node DeferredNode.new(parent: current_node, &)

      def add_node(child) = current_node.add_child child

      # dx/block
      def content_for(key, &content_block)
        if content_block
          root.content_for__add key, ContentForNode.new(parent: current_node).with(&content_block)
        elsif content_for?(key)
          content_for!(key)
        else
          current_node.add_child DeferredNode.new(parent: current_node) { content_for!(key) }
        end
      end

      # dx/block
      def content_for?(key) = root.content_for?(key)

      # dx/block
      def content_for!(key) = root.content_for__place key, current_node
    end
  end

  class CodeNode < AbstractNode
    def initialize(src:, parent:)
      super(parent:)

      @src = src

      @placeholders = src
                      .to_enum(:scan, placeholder_re)
                      .map { Regexp.last_match }
                      .map { Cecil::CodeNode::Placeholder.new(_1) }
    end

    def build_child(src:) = root.build_child(src:, parent: self)

    class << self
      # dx/customization
      def helpers(&)
        @helpers = Module.new(&) if block_given?
        @helpers ||= Module.new
        @helpers
      end
    end

    # dx/node
    def with(*args, **options, &block)
      raise "Expects args or opts but not both" if args.any? && options.any?

      self.children = []

      if @placeholders.any?
        @src = Cecil.interpolate(@src, @placeholders, args, options)
        @replaced = true
      end

      root.with_node(self, &block) if block

      self
    end

    # dx/node
    alias call with

    # dx/node
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

    # configurable
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

    # configurable
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

      Cecil.reindent("#{stack.join.strip}\n", depth, indent_chars)
    end

    # dx/node
    def <<(item)
      case item
      in CodeNode then nil
      in String then root.src(item)
      end
    end

    # configurable
    def placeholder_ident_re = /[[:alnum:]_]+/

    # configurable
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
      src = Cecil.reindent(@src, depth, indent_chars)

      src += "\n" unless src.end_with?("\n")
      src
    end

    # configurable
    def indent_chars = "    "
  end

  module Code
    module_function

    # dx/module
    def call(out = $DEFAULT_OUTPUT, &)
      builder = Builder::Generic.new
      BlockContext.new(builder, CodeNode.helpers).instance_exec(&)
      builder
        .root
        .evaluate!
        .stringify
        .lstrip
        .then { out << _1 }
    end

    # dx/module
    def generate_string(&) = call("", &)
  end

  def self.reindent(src, depth, indent_chars)
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
    else
      raise "Expects args or opts but not both: #{subs.inspect}"
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

  # TODO: test that it can access methods (and therefore should not inherit from BasicObject)
  # TODO: test that helpers works
  class BlockContext
    def initialize(builder, helpers)
      @builder = builder
      extend helpers
    end

    # def src, ``
    def src(...) = @builder.src(...)
    alias :` :src

    # def defer
    def defer(...) = @builder.defer(...)

    # def content_for, def content_for?, content_for!
    def content_for(...) = @builder.content_for(...)
    def content_for?(...) = @builder.content_for?(...)
    def content_for!(...) = @builder.content_for!(...)
  end
end
