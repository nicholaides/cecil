require_relative "content_for"
require_relative "nodes"

require "forwardable"

module Cecil
  class Builder
    attr_accessor :root, :config

    extend Forwardable
    def_delegators :@content_for, :content_for, :content_for!, :content_for?

    def initialize(config)
      @config = config
      @root = Nodes::RootNode.new(self)
      @active_nodes = [@root]

      @content_for = ContentFor.new do |on|
        on.store do |&block|
          Nodes::ContentForNode.new(parent: current_node, &block)
        end

        on.place do |node|
          node.place_content current_node
        end

        on.defer do |&block|
          current_node.add_child Nodes::DeferredNode.new(parent: current_node, &block)
        end
      end
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

    def defer(&) = add_node Nodes::DeferredNode.new(parent: current_node, &)

    def add_node(child)
      current_node.add_child child
      child
    end
  end
end
