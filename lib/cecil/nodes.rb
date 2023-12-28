require_relative "content_for"
require_relative "text"

module Cecil
  module Nodes
    # @!visibility private
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
      # @!visibility private
      attr_accessor :parent

      # @!visibility private
      def initialize(parent:)
        self.parent = parent
      end

      # @!visibility private
      def builder = root.builder

      # @!visibility private
      def root = parent.root

      # @!visibility private
      def depth = parent.depth + 1

      # @!visibility private
      def evaluate! = self

      # @!visibility private
      # TODO: we do need this, right? the tests don't seem to think so
      def replace_child(...) = nil

      # Add placeholder values and/or nest a block of code.
      #
      # Placeholder values can be given as positional arguments or named values
      #
      # When called with a block, the block is called immediately and any source
      # code emitted in that is nested under the current block.
      #
      # @overload with(*positional_values)
      #   @return [CodeLiteralNode]
      # @overload with(*positional_values, &)
      #   @return [CodeLiteralWithChildrenNode]
      # @overload with(**named_values)
      #   @return [CodeLiteralNode]
      # @overload with(**named_values, &)
      #   @return [CodeLiteralWithChildrenNode]
      # @overload with(&)
      #   @return [CodeLiteralWithChildrenNode]
      def with(...) = raise "Not implemented"
    end

    # Node that will be replaced with its children, after the rest of the
    # document is evaluated.
    #
    # Created by calling {BlockContext#defer} or by the internal workings of {BlockContext#content_for}.
    # @see BlockContext#defer
    # @see BlockContext#content_for
    class DeferredNode < AbstractNode
      # @!visibility private
      def initialize(**, &)
        super(**)

        @evaluate = lambda do
          ContainerNode.new(**, &)
                       .tap { root.replace_child self, _1 }
        end
      end

      # @!visibility private
      def evaluate!(...) = @evaluate.call(...)
    end

    # @!visibility private
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

    # @!visibility private
    class ContainerNode < AbstractNode
      include AsParentNode

      def depth = parent.depth
    end

    # Node that will be inserted in another location in the document.
    #
    # Created by {BlockContext#content_for}
    #
    # @see BlockContext#content_for
    class DetachedNode < ContainerNode
      # @!visibility private
      attr_accessor :root

      # @!visibility private
      def initialize(root, &)
        @root = root
        super(parent: nil, &)
      end

      # @!visibility private
      def attach_to(new_parent)
        self.parent = new_parent
        new_parent.add_child self
      end
    end

    # Node with source code, no placeholders, and no child nodes
    class CodeLiteralNode < AbstractNode
      # @!visibility private
      def self.build(...)
        klass = block_given? ? CodeLiteralWithChildrenNode : self
        klass.new(...)
      end

      # @!visibility private
      def initialize(src:, **)
        super(**)
        @src = src
      end

      # @overload with(&)
      #
      # Behaves like {TemplateNode#with}, except does not accept any arguments
      # because a node of this type has no placeholders.
      #
      # @see TemplateNode#with
      def with(*args, **options, &)
        raise "Has no placeholders" if args.any? || options.any?

        raise "Has no block" unless block_given?

        self.class.build(src: @src, parent:, &)
            .tap { builder.replace_node self, _1 }
      end

      alias call with
      alias [] with

      def stringify_src(syntax)
        src = Text.reindent(@src, depth, syntax.indent_chars)
        src += "\n" unless src.end_with?("\n")
        src
      end

      alias stringify stringify_src

      # TODO: do we need to define #<< ?
    end

    class CodeLiteralWithChildrenNode < CodeLiteralNode
      include AsParentNode

      # @!visibility private
      def closers(syntax)
        # TODO: test the @src.strip
        closing_brackets = Text.closers(@src.strip, syntax.block_ending_pairs).to_a

        Text.reindent("#{closing_brackets.join.strip}\n", depth, syntax.indent_chars)
      end

      # @!visibility private
      def stringify(...)
        [
          stringify_src(...),
          *stringify_children(...),
          *closers(...)
        ].join
      end

      def <<(item)
        case item
        in CodeLiteralNode then nil # TODO: test this... where should << be defined?
        in String then builder.src(item)
        end
      end
    end

    class TemplateNode < AbstractNode
      # @!visibility private
      def self.build(src:, builder:, **)
        placeholders = builder.syntax.scan_for_placeholders(src)

        if placeholders.any?
          new(src:, placeholders:, **)
        else
          CodeLiteralNode.new(src:, **)
        end
      end

      # @!visibility private
      def initialize(src:, placeholders:, **)
        super(**)
        @src = src
        @placeholders = placeholders
      end

      # @see AbstractNode#with
      def with(*positional_values, **named_values, &)
        src =
          case [positional_values, named_values, @placeholders]
          in [], {}, []
            @src
          in [], _, _
            Text.interpolate_named(@src, @placeholders, named_values)
          in _, {}, _
            Text.interpolate_positional(@src, @placeholders, positional_values)
          else
            raise "Method expects to be called with either named arguments or positional arguments but not both"
          end

        CodeLiteralNode
          .build(src:, parent:, &)
          .tap { builder.replace_node self, _1 }
      end

      alias call with
      alias [] with

      # @!visibility private
      # Raises If this method is called, it means that the placeholder values
      # were never given (i.e. {#with}/{#[]} was never called).
      def stringify(*) = raise "Mismatch?"
    end
  end
end
