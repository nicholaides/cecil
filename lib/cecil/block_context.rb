require "forwardable"

module Cecil
  # TODO: test that it can access methods (and therefore should not inherit from BasicObject)
  # TODO: test that helpers works
  class BlockContext
    def initialize(builder, helpers)
      @builder = builder
      extend helpers
    end

    extend Forwardable
    def_delegators :@builder, :src, :defer, :content_for, :content_for!, :content_for?

    alias :` :src
  end
end
