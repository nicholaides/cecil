require_relative "cecil/version"
require_relative "cecil/builder"
require_relative "cecil/block_context"
require_relative "cecil/code"

module Cecil # rubocop:disable Style/Documentation
  # @!visibility private
  def self.generate(out:, syntax_class:, &)
    out << Builder.new(syntax_class).build(&)
  end
end
