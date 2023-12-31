require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  def self.generate(syntax_class:, out:, &)
    builder = Builder.new(syntax_class.new)
    BlockContext.new(builder, syntax_class::Helpers).instance_exec(&)

    builder
      .root
      .evaluate!
      .stringify
      .lstrip
      .then { out << _1 }
  end

  # The {Code} class inherits from {Syntax} and serves as the base class for
  # generating source code using Cecil. Subclassing {Code} allows customizing
  # the syntax helpers and defining custom syntax rules.
  #
  # To define your own syntax, subclass {Code} and override methods defined in {Syntax}.
  class Code < Syntax
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
      def generate(out = $stdout, &) = Cecil.generate(syntax_class: self, out:, &)

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
      def generate_string(&) = generate("", &)
    end
  end
end
