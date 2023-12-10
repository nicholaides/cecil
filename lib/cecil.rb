require_relative "cecil/version"

module Cecil
  module AsParentNode
    def initialize(**, &)
      super(**)

      @children = []
      add_to_root(&)
    end

    def add_to_root(&) = root.build_node(self, &)

    def build_child(**) = root.build_child(**, parent: self)

    def children = @children

    def children=(children)
      @children = children
    end

    def add_child(child) = children << child

    def evaluate!
      children&.map!(&:evaluate!)
      super
    end

    def replace_child(old_node, new_node)
      if idx = children.index(old_node)
        children[idx] = new_node
      else
        children.each { _1.replace_child(old_node, new_node) }
      end
    end

    def stringify_children(...) = children.map { _1.stringify(...) }

    def stringify(...) = stringify_children(...).join
  end

  class AbstractNode
    attr_accessor :parent

    def initialize(parent:)
      self.parent = parent
    end

    def builder = root.builder
    def root = parent.root
    def depth = parent.depth + 1

    def evaluate! = self

    # TODO: we do need this, right? the tests don't seem to think so
    def replace_child(...) = nil
  end

  class DeferredNode < AbstractNode
    def initialize(**, &)
      super(**)

      @evaluate = lambda do
        ContainerNode.new(**, &)
                     .tap { root.replace_child self, _1 }
      end
    end

    def evaluate!(...) = @evaluate.call(...)
  end

  class RootNode < AbstractNode
    include AsParentNode

    attr_accessor :builder

    def initialize(builder)
      @builder = builder

      super(parent: nil)
    end

    def root = self
    def depth = -1

    def add_to_root(...) = nil

    def build_node(...) = builder.build_node(...)

    def build_child(src:, parent: self) = TemplateNode.build(src:, parent:, builder:)
  end

  class ContainerNode < AbstractNode
    include AsParentNode

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

  class Builder
    attr_accessor :root, :config

    def initialize(config)
      @config = config
      @root = RootNode.new(self)
      @active_nodes = [@root]
      @content_for = Hash.new { |hash, key| hash[key] = [] }
    end

    def current_node = @active_nodes.last || raise("No active Cecil node...")
    def replace_node(...) = current_node.replace_child(...)

    def build_node(code)
      @active_nodes.push code
      yield
    ensure
      @active_nodes.pop
    end

    def src(src) = add_node current_node.build_child(src:)

    def defer(&) = add_node DeferredNode.new(parent: current_node, &)

    def add_node(child)
      current_node.add_child child
      child
    end

    def content_for(key, &)
      if block_given?
        content_for__add key, ContentForNode.new(parent: current_node, &)
      elsif content_for?(key)
        content_for!(key)
      else
        current_node.add_child DeferredNode.new(parent: current_node) { content_for!(key) }
      end
    end

    def content_for?(key) = @content_for.key?(key)

    def content_for__add(key, child_container) = @content_for[key] << child_container

    def content_for!(key)
      @content_for.fetch(key).each { _1.place_content current_node }
    end
  end

  class CodeLiteralNode < AbstractNode
    def self.build(...)
      klass = block_given? ? CodeLiteralWithChildrenNode : self
      klass.new(...)
    end

    def initialize(src:, **)
      super(**)
      @src = src
    end

    def with(*args, **options, &)
      raise "Has no placeholders" if args.any? || options.any?

      self.class.build(src: @src, parent:, &)
          .tap { builder.replace_node self, _1 }
    end

    # dx/node
    alias call with
    alias [] with

    def stringify_src(config)
      src = Cecil.reindent(@src, depth, config.indent_chars)
      src += "\n" unless src.end_with?("\n")
      src
    end

    def stringify(...)= stringify_src(...)

    # TODO: do we need to define #<< ?
  end

  class CodeLiteralWithChildrenNode < CodeLiteralNode
    include AsParentNode

    def closers(config)
      stack = []

      src = @src.strip

      while src.size > 0 # rubocop:disable Style/ZeroLengthPredicate
        opener, closer = config.block_ending_pairs.detect { |l, _r| src.end_with?(l) } || break
        stack.push closer
        src = src[0...-opener.size]
      end

      Cecil.reindent("#{stack.join.strip}\n", depth, config.indent_chars)
    end

    def stringify(...)
      [
        stringify_src(...),
        *stringify_children(...),
        *closers(...)
      ].join
    end

    # dx/node
    def <<(item)
      case item
      in CodeLiteralNode then nil # TODO: test this... where should << be defined?
      in String then builder.src(item)
      end
    end
  end

  class TemplateNode < AbstractNode
    def self.build(src:, builder:, **)
      placeholders ||= src
                       .to_enum(:scan, builder.config.placeholder_re)
                       .map { Regexp.last_match }
                       .map { Cecil::Placeholder.new(_1) }

      if placeholders.any?
        new(src:, placeholders:, **)
      else
        CodeLiteralNode.new(src:, **)
      end
    end

    def initialize(src:, placeholders:, **)
      super(**)
      @src = src
      @placeholders = placeholders
    end

    # dx/node
    def with(*args, **options, &)
      raise "Expects args or opts but not both" if args.any? && options.any?

      CodeLiteralNode
        .build(
          src: Cecil.interpolate(@src, @placeholders, args, options),
          parent:,
          &
        )
        .tap { builder.replace_node self, _1 }
    end

    # dx/node
    alias call with
    alias [] with

    # has placeholders but .with was never called
    def stringify(*) = raise "Mismatch?"
  end

  class Placeholder
    attr_reader :ident, :offset_start, :offset_end

    def initialize(match)
      @ident = match[:placeholder]
      @offset_start, @offset_end = match.offset(0)
    end

    def range = offset_start...offset_end
  end

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

  def self.reindent(src, depth, indent_chars)
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

  def self.interpolate(template, placeholders, args, options)
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

    def src(...) = @builder.src(...)
    alias :` :src

    def defer(...) = @builder.defer(...)

    def content_for(...) = @builder.content_for(...)
    def content_for?(...) = @builder.content_for?(...)
    def content_for!(...) = @builder.content_for!(...)
  end
end
