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

    def self.cannot_reindent(template_str)
      it "cannot reindent \"#{template_str}\"" do
        expect do
          reindent(template_str, 3, "~~")
        end.to raise_error(/ambiguous/i)
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

    # unambiguous indentation because line 2 is indented more than line 3
    reindents \
      "|func() {
       |  level 1
       |}"

    # unambiguous indentation because line 3, while only whitespace, tells us
    # where the indentation is
    reindents \
      "|func():
       |  level 1
       <"

    # In this situation, there's no way of knowing what the intention was. Should it be:
    # ```
    # def python_fn():
    #   pass
    # ```
    #   or
    # ````
    # def python_fn():
    # pass
    # ````
    cannot_reindent \
      "|def python_fn():
       |  pass"

    # unambiguous b/c line 2 ("  def python_fn():") starts with indentation
    reindents ">
      |def python_fn():
      |  pass"

    # In this situation, there's no way of knowing what the intention was. Should it be:
    # ```
    # def ruby_fn():
    #   end
    # ```
    #   or
    # ````
    # def ruby_fn():
    # end
    # ````
    cannot_reindent \
      "|def ruby_fn
       |end"

    # unambiguous b/c line 2 ("  def ruby_fn") starts with indentation
    reindents ">
       |def ruby_fn
       |end"

    reindents \
      "|def ruby_fn
       |end
       <"

    reindents \
      "|const x
       <"

    reindents "|one line"

    reindents "|  one line"

    reindents "|  one line  "
  end
end
