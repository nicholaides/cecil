require_relative "../helpers/reindent_helpers"

RSpec.describe Cecil::Text do
  include Cecil::Text

  describe ".scan_for_re_matches" do
    it "returns matches" do
      matches = scan_for_re_matches("a b c d", /\w+/)
      match_strs = matches.map { _1[0] }
      expect(match_strs).to eq %w[a b c d]
    end
  end

  describe ".reindent" do
    def self.reindents(template_str)
      describe "reindents \"#{template_str}\"" do
        template = IndentationTemplate.new(template_str)
        (0...3).each do |level| # rubocop:disable Style/EachForSimpleLoop
          specify "to level #{level}" do
            actual = reindent(template.as_input, level, "~~")
            expected = template.indented "~~" * level
            expect(actual).to eq expected
          end
        end
      end
    end

    reindents ">
      |func {
      |  level 1
      |}
    <"

    reindents ">
      |func():
      |  level 1
    <"

    reindents ">
      |func():
      |  level 1
    <"

    reindents ">
      |func():
      |  level 1

    <"

    reindents ">

      |func():
      |  level 1

    <"

    reindents \
      "|func() {
       |  level 1
       |}"

    reindents \
      "|func():
       |  level 1
       <"

    # In this situation, there's no way of knowing what the intention was. e.g. was it:
    # `func():
    # level1`
    #   or
    # `funct():
    #   leve1`?
    # We should probably throw an error to prevent unintentional mistakes
    # e.g.:
    # `func():
    #   level 1`
    reindents \
      "|func():
       |level 1"

    reindents "|one line"

    reindents "|  one line"

    reindents "|  one line  "
  end
end
