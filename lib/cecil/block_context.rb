require "forwardable"

module Cecil
  # The BlockContext contains methods available to you inside a Cecil block.
  # This includes the methods below as well as any helpers passed in by your Syntax.
  #
  # TODO: test that it can access methods (and therefore should not inherit from BasicObject)
  # TODO: test that helpers works
  class BlockContext
    # @!visibility private
    def initialize(builder, helpers)
      @builder = builder
      extend helpers
    end

    extend Forwardable

    # @!method src(source_string)
    #   Inserts a node with the given source string.
    #
    #   The inserted node can be modified by calling
    #   {Nodes::AbstractNode#with}/{Nodes::AbstractNode#[]}
    #
    #   @return [Nodes::AbstractNode] the inserted node
    #
    #   @overload src(source_string)
    #   @overload `(source_string)
    def_delegator :@builder, :src

    # Alias for {#src}
    def `(source_string) = @builder.src(source_string)

    # @!method defer(&)
    #   Defer execution of the the given block until the rest of the document is
    #   evaluated and insert any content in the document where this method was
    #   called.
    #   @return [Nodes::DeferredNode]
    def_delegator :@builder, :defer

    # @!method content_for(key, &)
    #   Stores content for the given key to be insert at a different location in
    #   the document.
    #
    #   If a block is passed, it will be executed and the result stored.
    #   If no block is passed but the key already has content, it will be retrieved.
    #   Otherwise, content rendering will be deferred until later.
    #
    #   @param [#hash] key Any hashable object to identify the content but can
    #     be anything that works as a hash key
    #
    #   @return [nil]
    #
    #   @example Storing content for earlier insertion
    #     content_for :imports # inserts `import { Component } from 'react'` here
    #     # ...
    #     content_for :imports do # store
    #       `import { Component } from 'react'`
    #     end
    #
    #   @example Storing content for later insertion
    #     `job1 = new Job()`
    #     content_for :run_jobs do # store
    #       `job1.run()`
    #     end
    #
    #     `job2 = new Job()`
    #     content_for :run_jobs do # store
    #       `job2.run()`
    #     end
    #     # ...
    #     content_for :run_jobs # adds `job1.run()` and `job2.run()`
    #
    #   @example Storing multiple lines
    #     content_for :functions
    #
    #     content_for :functions do
    #       `function $fnName() {`[fn_name] do
    #         `api.fetch('$fnName', $fn_arg)`[fn_name, fn_arg.to_json]
    #       end
    #       `function undo$fnName() {`[fn_name] do
    #         `api.fetch('undo$fnName', $fn_arg)`[fn_name, fn_arg.to_json]
    #       end
    #     end
    #
    #   @example Using different types for keys
    #     content_for :imports
    #     content_for "imports"
    #     content_for ["imports", :secion1]
    #
    #     user = User.find(1)
    #     content_for user
    #
    #   @overload content_for(key)
    #     Insert the stored content for the given key
    #     @return [nil] A node of stored content for the given key
    #
    #   @overload content_for(key, &)
    #     Store content to be be inserted at a different position in the file
    #     @yield The content in the block is evaluated immediately and stored for later insertion
    #     @return [nil]
    def_delegator :@builder, :content_for

    # @!method content_for?(key)
    #   Returns whether there is any content stored for the given key. This method
    #     returns immediately and will return false even if `#content_for(key) { ... }` is called later.
    #   @param [#hash] key Any hashable object to identify the content
    #   @return [Boolean] whether any content is stored for the given key
    def_delegator :@builder, :content_for?

    # @!method content_for!(key)
    #   Returns the content stored for the given key, and raises an exception if
    #   there is no content stored. Calling {#content_for!} is evaluated
    #   immeditately and will raise an exception even if
    #   `#content_for(key) { ... }` is called later.
    #
    #   @param [#hash] key Any hashable object to identify the content
    #   @return [Array<Nodes::DetachedNode>] A node of stored content for the given key
    #   @throw [Exception] Throws an execption if there is no content stored at the given key
    def_delegator :@builder, :content_for!
  end
end
