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

      def stringify_children = children.map(&:stringify)

      def stringify = stringify_children.join
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

      # Provide values for placeholders and/or nest a block of code. When
      # called, will replace this node with a {CodeLiteralNode} or
      # {CodeLiteraleWithChildrenNode}
      #
      # Placeholder values can be given as positional arguments or named values,
      # but not both.
      #
      # When called with a block, the block is called immediately and any source
      # code emitted is nested under the current block.
      #
      # @return [AbstractNode]
      #
      # @overload with(*positional_values)
      # @overload with(**named_values)
      # @overload with(*positional_values, &)
      # @overload with(**named_values, &)
      # @overload with(&)
      #
      # @example Positional values are replaced in the order given
      #   `const $field = $value`["user", "Alice".to_json]
      #   # const user = "Alice"
      #
      # @example Positional values replace all placeholders with the same name
      #   `const $field: $Namespace.$Class = new $Namespace.$Class()`["user", "Models", "User"]
      #   # const user: Models.User = new Models.User()
      #
      # @example Named values replace all placeholders with the given name
      #   `const $field = $value`[field: "user", value: "Alice".to_json]
      #   # const user = "Alice"
      #
      #   `const $field: $Class = new $Class()`[field: "user", Class: "User"]
      #   # const user: User = new User()
      #
      # @example Blocks indent their emitted contents (see {Syntax#indent_chars})
      #   `class $Class {`["User"] do
      #     `public $field: $type`["name", "string"]
      #
      #     # multiline nodes still get indented correctly
      #     `get id() {
      #       return this.name
      #     }`
      #
      #     # nodes can nest arbitrarily deep
      #     `get $field() {`["upperCaseName"] do
      #       `return this.name.toUpperCase()`
      #     end
      #   end
      #
      #   # class User {
      #   #   public name: string
      #   #   get id() {
      #   #     return this.name
      #   #   }
      #   #   get upperCaseName() {
      #   #     return this.name.toUpperCase()
      #   #   }
      #   # }
      #
      # @example Blocks close trailing open brackets (defined in {Syntax#block_ending_pairs})
      #   `ids = new Set([`[] do
      #     `1, 2, 3`
      #   end
      #   # ids = new Set([
      #   #   1, 2, 3
      #   # ])
      #
      # @see Syntax
      def with(*positional_values, **named_values, &) = raise "Not implemented" # rubocop:disable Lint/UnusedMethodArgument

      # Alias of {#with}
      # @return [AbstractNode]
      def [](...)
        # don't use alias/alias_method b/c subclasses overriding `with` need `[]` to call `self.with`
        with(...)
      end

      # Append a string or node to the node, without making a new line.
      #
      # @param string_or_node [String, AbstractNode]
      # @return [AbstractNode]
      #
      # @example Append a string to close brackets that aren't closed automatically
      #   `test("quacks like a duck", () => {`[] do
      #     `expect(duck)`
      #   end << ')' # closes open bracket from "test("
      #
      #   # test("quacks like a duck", () => {
      #   #   expect(duck)
      #   # })
      #
      # @example Use backticks to append brackets
      #   `test("quacks like a duck", () => {`[] do
      #     `expect(duck)`
      #   end << `)` # closes open bracket from "test("
      #
      #   # test("quacks like a duck", () => {`
      #   #   expect(duck)
      #   # })
      def <<(string_or_node) = raise "Not implemented" # rubocop:disable Lint/UnusedMethodArgument
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

    # Node with source code, no placeholders, and no child nodes.
    #
    # Will not accept any placeholder values, but can receive children via
    # {#with}/{#[]} and will replace itself with a {CodeLiteralWithChildrenNode}.
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

      def with(*args, **options, &)
        raise "Has no placeholders" if args.any? || options.any?

        raise "Has no block" unless block_given?

        self.class.build(src: @src, parent:, &)
            .tap { builder.replace_node self, _1 }
      end

      # @!visibility private
      def stringify_src
        src = Text.reindent(@src, depth, builder.syntax.indent_chars)
        src += "\n" unless src.end_with?("\n")
        src
      end

      # @!visibility private
      alias stringify stringify_src

      # TODO: do we need to define #<< ?
    end

    # Node with source code, no placeholders, and child nodes
    class CodeLiteralWithChildrenNode < CodeLiteralNode
      include AsParentNode

      # @!visibility private
      def closers
        # TODO: test the @src.strip
        closing_brackets = Text.closers(@src.strip, builder.syntax.block_ending_pairs).to_a

        Text.reindent("#{closing_brackets.join.strip}\n", depth, builder.syntax.indent_chars)
      end

      # @!visibility private
      def stringify
        [
          stringify_src,
          *stringify_children,
          *closers
        ].join
      end

      # See {AbstractNode#<<}
      # @return [AbstractNode]
      def <<(string_or_node)
        case string_or_node
        in CodeLiteralNode then nil # TODO: test this... where should << be defined?
        in String then builder.src(string_or_node)
        end
      end
    end

    # A node that has placeholders but does not yet have values or chilren.
    # Created with backticks or {BlockContext#src `` #`(code_str) ``}
    #
    # When {#with}/{#[]} is called on the node, it will replace itself with a
    # {CodeLiteralNode} or {CodeLiteralNodeWithChildren}
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

      # @!visibility private
      # If this method is called, it means that the placeholder values were
      # never given (i.e. {#with}/{#[]} was never called).
      def stringify = raise "Mismatch?"
    end
  end
end
