module Cecil
  class ContentFor
    def initialize(store: nil, place: nil, defer: nil)
      @store = store
      @place = place
      @defer = defer

      yield self

      @content = Hash.new { |hash, key| hash[key] = [] }
    end

    def store(&block) = @store = block
    def place(&block) = @place = block
    def defer(&block) = @defer = block

    def content_for(key, &)
      if block_given?
        @content[key] << @store.call(&)
      elsif content_for?(key)
        content_for!(key)
      else
        @defer.call { content_for!(key) }
      end
    end

    def content_for?(key) = @content.key?(key)

    def content_for!(key) = @content.fetch(key).each(&@place)
  end
end
