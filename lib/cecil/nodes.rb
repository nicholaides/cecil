require_relative "text"

module Cecil
  module AsParentNode
    def self.included(base)
      base.attr_accessor :children
    end

    def initialize(**, &)
      super(**)

      self.children = []
      add_to_root(&)
    end

    def add_to_root(&) = root.build_node(self, &)

    def build_child(**) = root.build_child(**, parent: self)

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
      src = Cecil::Text.reindent(@src, depth, config.indent_chars)
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

      Cecil::Text.reindent("#{stack.join.strip}\n", depth, config.indent_chars)
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
          src: Cecil::Text.interpolate(@src, @placeholders, args, options),
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
end