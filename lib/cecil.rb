require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/code"

module Cecil
  # @!visibility private
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
end
