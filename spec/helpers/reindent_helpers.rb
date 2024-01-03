IndentationTemplate = Struct.new(:template) do
  # | => beginning of line up to "|" gets replaced with new indentation
  # < => beginning of line to "<" gets deleted
  # > => delete from > through end of line
  def as_input
    template
      .gsub("|", "")
      .gsub(">", "")
      .gsub("<", "")
  end

  def indented(indentation)
    template
      .gsub(/^[ \t]*\|/, indentation)
      .gsub(/^[ \t]*</, "")
      .gsub(/>[ \t]*\R/, "")
  end
end
