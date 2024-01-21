require_relative "content_for"
require_relative "text"
require_relative "indentation"

module Cecil
  class Node
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
    def replace_child(...) = nil

    # @!visibility private
    def reattach_to(new_parent)
      parent.remove_child self

      self.parent = new_parent
      new_parent.add_child self
    end

    # @!visibility private
    def replace_with(node) = builder.replace_node self, node

    # Provide values for placeholders and/or nest a block of code. When called, will replace this node with a {Literal}
    # or {LiteralWithChildren}.
    #
    # Placeholder values can be given as positional arguments or named values, but not both.
    #
    # When called with a block, the block is called immediately and any source code emitted is nested under the current
    # block.
    #
    # @return [Node]
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
    # @example Blocks indent their emitted contents (see {Code#indent_chars})
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
    # @example Blocks close trailing open brackets (defined in {Code#block_ending_pairs})
    #   `ids = new Set([`[] do
    #     `1, 2, 3`
    #   end
    #   # ids = new Set([
    #   #   1, 2, 3
    #   # ])
    #
    # @example Can be called with no parameters to nest a block
    #   `ids = new Set([`[] do
    #     `1, 2, 3`
    #   end
    # @see Code
    def with(*positional_values, **named_values, &) = raise "Not implemented" # rubocop:disable Lint/UnusedMethodArgument

    # Alias of {#with}
    # @return [Node]
    def [](...)
      # don't use alias/alias_method b/c subclasses overriding `with` need `[]` to call `self.with`
      with(...)
    end

    # Append a string or node to the node, without making a new line.
    #
    # @param string_or_node [String, Node]
    # @return [Node]
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
    def <<(string_or_node)
      SameLineContainer.new(parent:).tap do |container|
        container.add_child self
        replace_with container
      end << string_or_node
    end

    # @!visibility private
    module AsParent
      def self.included(base)
        base.attr_accessor :children
      end

      def initialize(**kwargs, &)
        super(**kwargs)

        self.children = []
        add_to_root(&)
      end

      def add_to_root(&) = builder.build_node(self, &)

      def build_child(**kwargs) = root.build_child(**kwargs, parent: self)

      def add_child(child) = children << child

      def evaluate!
        children&.map!(&:evaluate!)
        super
      end

      def remove_child(child) = children.delete(child)

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

    # Node that will be replaced with its children, after the rest of the document is evaluated.
    #
    # Created by calling {BlockContext#defer} or by the internal workings of {BlockContext#content_for}.
    #
    # @see BlockContext#defer
    # @see BlockContext#content_for
    class Deferred < Node
      # @!visibility private
      def initialize(**kwargs, &block) # rubocop:disable Style/ArgumentsForwarding,Naming/BlockForwarding
        super(**kwargs)

        @evaluate = lambda do
          Container.new(**kwargs, &block) # rubocop:disable Style/ArgumentsForwarding,Naming/BlockForwarding
                   .tap { root.replace_child self, _1 }
        end
      end

      # @!visibility private
      def evaluate!(...) = @evaluate.call(...)
    end

    # @!visibility private
    class RootNode < Node
      include AsParent

      attr_accessor :builder

      def initialize(builder)
        @builder = builder

        super(parent: nil)
      end

      def root = self
      def depth = -1

      def add_to_root(...) = nil

      def build_node(...) = builder.build_node(...)

      def build_child(src:, parent: self) = Template.build(src:, parent:, builder:)
    end

    # @!visibility private
    class Container < Node
      include AsParent

      def depth = parent.depth
    end

    # Node that contains child nodes that were appended to via {Node#<<}.
    class SameLineContainer < Container
      # @!visibility private
      def initialize(parent:)
        super(parent:) do
          yield self if block_given?
        end
      end

      # @!visibility private
      def stringify
        *firsts, last = stringify_children
        firsts_without_trailing_newline = firsts.map { _1.sub(/\R\z/m, "") }
        [*firsts_without_trailing_newline, last].join
      end

      # @!visibility private
      def <<(string_or_node)
        case string_or_node
        in Node => node
          node.reattach_to self
        in String => string
          builder.build_node(self) { builder.src string }
        end

        self
      end
    end

    # Node that will be inserted in another location in the document.
    #
    # Created by {BlockContext#content_for} with a block.
    #
    # @see BlockContext#content_for
    class Detached < Container
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

    # Node with source code, no placeholders, and no child nodes. Created by calling
    # {BlockContext#src `` #`(code_str) ``} with a string that has no placeholders.
    #
    # Will not accept any placeholder values, but can receive children via {#with}/{#[]} and will replace itself with a
    # {LiteralWithChildren}.
    class Literal < Node
      # @!visibility private
      def self.build(...)
        klass = block_given? ? LiteralWithChildren : self
        klass.new(...)
      end

      # @!visibility private
      def initialize(src:, **kwargs)
        super(**kwargs)
        @src = src
      end

      # @!visibility private
      def with(*args, **options, &)
        raise "This fragement has no placeholders. Fragment:\n#{@src}" if args.any? || options.any?

        raise "This method requires a block" unless block_given?

        self.class.build(src: @src, parent:, &)
            .tap { builder.replace_node self, _1 }
      end

      # @!visibility private
      def stringify_src
        src = Indentation.reindent(@src, depth, builder.syntax.indent_chars,
                                   handle_ambiguity: builder.syntax.handle_ambiguous_indentation)
        src += "\n" unless src.end_with?("\n")
        src
      end

      # @!visibility private
      alias stringify stringify_src
    end

    # Node with source code, no placeholders, and child nodes. Created by calling {BlockContext#src `` #`(code_str) ``}
    # with a string without placeholders and then calling {#with}/{#[]} on it.
    class LiteralWithChildren < Literal
      include AsParent

      # @!visibility private
      def closers
        closing_brackets = Text.closers(@src.strip, builder.syntax.block_ending_pairs).to_a

        Indentation.reindent("#{closing_brackets.join.strip}\n", depth, builder.syntax.indent_chars,
                             handle_ambiguity: builder.syntax.handle_ambiguous_indentation)
      end

      # @!visibility private
      def stringify
        [
          stringify_src,
          *stringify_children,
          *closers
        ].join
      end
    end

    # A node that has placeholders but does not yet have values or children. Created with backticks or
    # {BlockContext#src `` #`(code_str) ``}
    #
    # When {#with}/{#[]} is called on the node, it will replace itself with a {Literal} or {LiteralWithChildren}
    class Template < Node
      # @!visibility private
      def self.build(src:, builder:, **kwargs)
        placeholders = builder.syntax.scan_for_placeholders(src)

        if placeholders.any?
          new(src:, placeholders:, **kwargs)
        else
          Literal.new(src:, **kwargs)
        end
      end

      # @!visibility private
      def initialize(src:, placeholders:, **kwargs)
        super(**kwargs)
        @src = src
        @placeholders = placeholders
      end

      # @see Node#with
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

        Literal
          .build(src:, parent:, &)
          .tap { builder.replace_node self, _1 }
      end

      # @!visibility private
      def stringify = raise "This fragement has placeholders but was not given values. Fragment:\n#{@src}"
    end
  end
end
