require_relative "content_for"
require_relative "nodes"

require "forwardable"

module Cecil
  class Builder
    attr_accessor :root, :syntax

    extend Forwardable
    def_delegators :@content_for, :content_for, :content_for!, :content_for?

    def initialize(syntax)
      @syntax = syntax
      @root = Nodes::RootNode.new(self)
      @active_nodes = [@root]

      @content_for = ContentFor.new do |on|
        on.store do |&block|
          unattached_node(&block)
        end

        on.place do |content_for_node|
          content_for_node.move_to_parent current_node
        end

        on.defer do |&block|
          defer(&block)
        end
      end
    end

    def unattached_node(&) = Nodes::ContentForNode.new(root, &)

    def current_node = @active_nodes.last || raise("No active Cecil node...")
    def replace_node(...) = current_node.replace_child(...)

    def build_node(code)
      @active_nodes.push code
      yield
    ensure
      @active_nodes.pop
    end

    def src(src) = add_node current_node.build_child(src:)

    def defer(&) = add_node Nodes::DeferredNode.new(parent: current_node, &)

    def add_node(child)
      current_node.add_child child
      child
    end
  end
end
