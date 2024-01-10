require_relative "content_for"
require_relative "nodes"

require "forwardable"

module Cecil
  # @!visibility private
  class Builder
    attr_accessor :root, :syntax

    extend Forwardable
    def_delegators :@content_for, :content_for, :content_for!, :content_for?

    def initialize(syntax_class)
      @syntax = syntax_class.new
      @helpers = syntax_class::Helpers

      @root = Node::RootNode.new(self)
      @active_nodes = [@root]

      @content_for = ContentFor.new(
        store: method(:detached_node),
        place: method(:reattach_nodes),
        defer: method(:defer)
      )
    end

    def build(&block)
      @block_context = BlockContext.new(block.binding.receiver, self, @helpers)
      @block_context.instance_exec(&block)

      root
        .evaluate!
        .stringify
        .lstrip
    end

    def detached_node(&) = Node::Detached.new(root, &)

    def reattach_nodes(detached_nodes)
      container = Node::ContainerNode.new(parent: current_node) {} # rubocop:disable Lint/EmptyBlock
      detached_nodes.each { _1.attach_to container }
      add_node container
      container
    end

    def current_node = @active_nodes.last || raise("Not inside a Cecil block")
    def replace_node(...) = current_node.replace_child(...)

    def build_node(node)
      @active_nodes.push node
      yield
    ensure
      @active_nodes.pop
    end

    def src(src) = add_node current_node.build_child(src:)

    def defer(&) = add_node Node::Deferred.new(parent: current_node, &)

    def add_node(child)
      current_node.add_child child
      child
    end
  end
end
