require_relative "content_for"
require_relative "text"

module Cecil
  module Nodes
    module AsParentNode
      def self.included(base)
        base.attr_accessor :children
      end

      def initialize(**, &)
        super(**)

        self.children = []
        add_to_root(&)
      end

      def add_to_root(&) = builder.build_node(self, &)

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

    class DetachedNode < ContainerNode
      attr_accessor :root

      def initialize(root, &)
        @root = root
        super(parent: nil, &)
      end

      def attach_to(new_parent)
        self.parent = new_parent
        new_parent.add_child self
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

      def stringify_src(syntax)
        src = Text.reindent(@src, depth, syntax.indent_chars)
        src += "\n" unless src.end_with?("\n")
        src
      end

      def stringify(...)= stringify_src(...)

      # TODO: do we need to define #<< ?
    end

    class CodeLiteralWithChildrenNode < CodeLiteralNode
      include AsParentNode

      def closers(syntax)
        # TODO: test the @src.strip
        closing_brackets = Text.closers(@src.strip, syntax.block_ending_pairs).to_a

        Text.reindent("#{closing_brackets.join.strip}\n", depth, syntax.indent_chars)
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

    # A node generated by calling {BlockContext#src} or {BlockContext#``}.
    #
    # Placeholder values can be given by calling {#[]}/{#with}.
    class TemplateNode < AbstractNode
      def self.build(src:, builder:, **)
        placeholders = builder.syntax.scan_for_placeholders(src)

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

      # @overload with(*args)
      #   @return [CodeLiteralNode]
      # @overload with(**options)
      #   @return [CodeLiteralNode]
      # @overload with(*args, &)
      #   @return [CodeLiteralWithChildrenNode]
      # @overload with(**options, &)
      #   @return [CodeLiteralWithChildrenNode]
      def with(*args, **options, &)
        src =
          case [args, options, @placeholders]
          in [], {}, []
            @src
          in [], named_values, _
            Text.interpolate_named(@src, @placeholders, named_values)
          in positional_values, {}, _
            Text.interpolate_positional(@src, @placeholders, positional_values)

          in [], {}, _
            raise "Mismatch? The following placeholders expected values to be given, but none were: #{@placeholders.map(&:ident).uniq.join(", ")}"
          in _, {}, []
            raise "Mismatch? No placeholder values expected, but received #{args.size} values"
          in [], _, []
            raise "Mismatch? No placeholder values expected, but received values for #{options.keys.map(&:inspect).join(", ")}"
          else
            raise "Method expects to be called with either named arguments or positional arguments but not both"
          end

        CodeLiteralNode
          .build(src:, parent:, &)
          .tap { builder.replace_node self, _1 }
      end

      alias call with
      alias [] with

      # Raises If this method is called, it means that the
      #   placeholder values were never given (i.e. {#with}/{#[]} was never called).
      # @return [raises exception] Does not return, only raises an exception
      # @raise [Exception]
      def stringify(*) = raise "Mismatch?"
    end
  end
end
