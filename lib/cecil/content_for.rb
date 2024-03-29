module Cecil
  # @!visibility private
  class ContentFor
    def initialize(store:, place:, defer:)
      @store = store
      @place = place
      @defer = defer

      @content = Hash.new { |hash, key| hash[key] = [] }
    end

    def content_for(key, &)
      if block_given?
        @content[key] << @store.call(&)
        nil # so that users don't get access to the array of content
      elsif content_for?(key)
        content_for!(key)
      else
        @defer.call { content_for!(key) }
      end
    end

    def content_for?(key) = @content.key?(key)

    def content_for!(key) = @place.call(@content.fetch(key))
  end
end
