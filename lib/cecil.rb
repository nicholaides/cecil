require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  # The {Code} class inherits from {Syntax} and serves as the base class for
  # generating source code using Cecil. Subclassing {Code} allows customizing
  # the syntax helpers and defining custom syntax rules.
  #
  # To define your own syntax, subclass {Code} and override methods defined in {Syntax}.
  class Code
    include Syntax

    class << self
      # Generates output by executing the given block and writing its return
      # value to the provided output buffer/stream
      #
      # The stream is written to by calling `#<<` with the generated source code.
      #
      # @param [#<<] out The output buffer/stream to write to
      # @yield The given block can use backticks (i.e.
      # {BlockContext#src `` #`(code_str) ``} ) to add lines of code to the
      # buffer/stream.
      # @return The returned value of `out <<`
      #
      # @example Outputing to stdout
      #   Cecil.generate do
      #     `function helloWorld() {}`
      #   end
      #
      # @example Outputing to a file
      #   File.open "output.js", "w" do |file|
      #     Cecil.generate file do
      #       `function helloWorld() {}`
      #     end
      #   end
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
      #
      # @yield (see .generate)
      # @return [String] The generated source code
      # @see .generate
      # @example
      #   my_code = Cecil.generate_string do
      #     `function helloWorld() {}`
      #   end
      #   puts my_code
      def generate_string(&)
        generate("", &)
      end

      # @overload helpers(&)
      #   Define helper methods for use inside the Cecil block. Each subclass
      #   of {Code} has its own helpers module.
      #
      #   E.g.
      #
      #       class HTML < Cecil::Code
      #         helpers do
      #           def h(str) = CGI.escape(str)
      #         end
      #       end
      #
      #       page = "My Geocities Site ~~< >~~"
      #       HTML.generate_string do
      #         `<title>$page</title>`[h page]
      #       end
      #
      #   @yield If given a block, calls the block inside a new Module and returns the module.
      #
      # @overload helpers
      #   @return [Module] the module with the helpers defined by calling .helpers with a block
      def helpers(&)
        @helpers ||= Module.new
        @helpers.module_exec(&) if block_given?
        @helpers
      end
    end

    def helpers = self.class.helpers
  end
end
