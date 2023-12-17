require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  class Code < Syntax
    class << self
      def call(out = $stdout, &)
        syntax = new
        builder = Builder.new(syntax)
        BlockContext.new(builder, syntax.helpers).instance_exec(&)
        builder
          .root
          .evaluate!
          .stringify(syntax)
          .lstrip
          .then { out << _1 }
      end

      def generate_string(&) = call("", &)

      def helpers(&)
        @helpers = Module.new(&) if block_given?
        @helpers ||= Module.new
        @helpers
      end
    end

    def helpers = self.class.helpers
  end
end
