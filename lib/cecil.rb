require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  class Code < Syntax
    class << self
      # Generates output and sends it to `out` via `<<`. `out` defaults to `$stdout`,
      # but can be any object that responds to `<<`.
      def generate(out = $stdout, &)
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
      alias call generate

      # Generates output and returns it as a string
      def generate_string(&) = generate("", &)

      # Define (or return) helpers for use inside the Cecil block. Each subclass
      # of `Code` has its own helpers.
      #
      # E.g.
      #   class HTML < Cecil::Code
      #     helpers do
      #       def h(str) = CGI.escape(str)
      #     end
      #   end
      #
      #   page = "My Geocities Site ~~< >~~"
      #   HTML.generate_string do
      #     `<title>$page</title>`[h page]
      #   end
      # If given a block, calls the block inside a new Module and returns the module.
      def helpers(&)
        @helpers ||= Module.new
        @helpers.module_exec(&) if block_given?
        @helpers
      end
    end

    def helpers = self.class.helpers
  end
end
