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
  end
end
