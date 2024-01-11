module Cecil
  # Represents the name and location of a placeholder in a string.
  Placeholder = Struct.new(:ident, :offset_start, :offset_end) do
    # @!attribute ident
    #   @return [String] the name of this placeholder. E.g. the `ident` of `${my_field}` would be `my_field`

    # @!attribute offset_start
    #   @return [Integer] the offset where this placeholder starts in the
    #     string. This number is usually taken from a Regexp match.

    # @!attribute offset_end
    #   @return [Integer] the offset where this placeholder ends in the
    #     string. This number is usually taken from a Regexp match.

    # Return the range that this placeholder occupies in the string
    # @return [Range(Integer)]
    def range = offset_start...offset_end

    # Mimicks Data#with, introduced in Ruby 3.2
    def with(**kwargs) = self.class.new(*to_h.merge(kwargs).values_at(*members))

    # Create a new {Placeholder} with one member transformed by the given block
    #
    # @example Make a new placeholder with ident in uppercase
    #   placeholder.transform_key(:ident, &:upcase)
    #
    # @param [Symbol] member
    # @return [Placeholder]
    def transform_key(member) = with(**{ member => yield(self[member]) })
  end
end
