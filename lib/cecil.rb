require_relative "cecil/version"
require_relative "cecil/nodes"

module Cecil
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
      current_node.add_child child
      child
    end

    def content_for(key, &)
      if block_given?
        content_for__add key, ContentForNode.new(parent: current_node, &)
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
