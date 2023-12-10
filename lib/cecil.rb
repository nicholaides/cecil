require_relative "cecil/version"

module Cecil
  class AbstractNode
    attr_accessor :parent, :children

    def initialize(parent:)
      @parent = parent
      @children = []
    end

    def builder = root.builder
    def root = parent.root
    def depth = parent.depth + 1

    def add_child(child) = children << child

    def evaluate!
      children&.map!(&:evaluate!)
      self
    end

    def stringify(config) = children.map { _1.stringify(config) }.join

    def replace_child(old_node, new_node)
      if idx = children.index(old_node)
        children[idx] = new_node
      else
        children.each { _1.replace_child(old_node, new_node) }
      end
    end
  end

  class DeferredNode < AbstractNode
    def initialize(parent:, &deferred_block)
      super(parent:)
      @deferred_block = deferred_block
      add_child ContainerNode.new(parent: self)
    end

    def child
      children => [container]
      container
    end

    def evaluate! = child.insert(&@deferred_block)

    def depth = parent.depth
  end

  class RootNode < AbstractNode
    attr_accessor :builder

    def initialize(builder)
      super(parent: nil)

      @builder = builder
    end

    def root = self
    def depth = -1

    def build_node(...) = builder.build_node(...)

    def build_child(src:, parent: self) = TemplateNode.build(src:, parent:, builder:)
  end

  class ContainerNode < AbstractNode
    def insert(&)
      root.build_node(self, &)
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
      current_node.add_child(child)
      child
    end

    def content_for(key, &content_block)
      if content_block
        content_for__add key, ContentForNode.new(parent: current_node).insert(&content_block)
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
    def self.build(src:, parent:, &block)
      if block
        CodeLiteralWithChildrenNode.new(src:, parent:, &block)
      else
        new(src:, parent:)
      end
    end

    def initialize(src:, parent:)
      super(parent:)
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

    def stringify(config)
      src = Cecil.reindent(@src, depth, config.indent_chars)
      src += "\n" unless src.end_with?("\n")
      src
    end

    # TODO: do we need to define #<< ?
  end

  class CodeLiteralWithChildrenNode < CodeLiteralNode
    def initialize(src:, parent:, &block)
      super(src:, parent:)

      self.children = [] # TODO: test this
      root.build_node(self, &block)
    end

    def build_child(src:) = root.build_child(src:, parent: self)

    def stringify(config)
      srcs = [super]

      srcs += children.map { _1.stringify(config) }

      close = begin
        stack = []

        src = @src.strip

        while src.size > 0 # rubocop:disable Style/ZeroLengthPredicate
          opener, closer = config.block_ending_pairs.detect { |l, _r| src.end_with?(l) } || break
          stack.push closer
          src = src[0...-opener.size]
        end

        Cecil.reindent("#{stack.join.strip}\n", depth, config.indent_chars)
      end
      srcs << close

      srcs.join
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
    def self.build(src:, parent:, builder:)
      placeholders ||= src
                       .to_enum(:scan, builder.config.placeholder_re)
                       .map { Regexp.last_match }
                       .map { Cecil::Placeholder.new(_1) }

      if placeholders.any?
        new(src:, parent:, placeholders:)
      else
        CodeLiteralNode.new(src:, parent:)
      end
    end

    def initialize(src:, parent:, placeholders:)
      super(parent:)
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
