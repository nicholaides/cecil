require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  class Code < Syntax
    def self.call(out = $stdout, &)
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

    def self.generate_string(&) = call("", &)
  end
end
