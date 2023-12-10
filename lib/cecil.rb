require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/syntax"

module Cecil
  class Code < Syntax
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
end
