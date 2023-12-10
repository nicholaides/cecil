require_relative "cecil/version"
require_relative "cecil/nodes"
require_relative "cecil/content_for"

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
