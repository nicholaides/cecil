require "cecil/indentation"
require_relative "../helpers/reindent_helpers"

RSpec.describe Cecil::Indentation do
  include described_class
  extend described_class

  describe ".reindent" do # rubocop:disable RSpec/EmptyExampleGroup
    def self.reindents(template_str, desc_more = " ", **kwargs)
      describe "given#{desc_more}\"#{template_str}\"" do
        template = IndentationTemplate.new(template_str)
        [0, 1, 2, 3, 10, 20].each do |level|
          it "reindents to level #{level}" do
            actual = reindent(template.as_input, level, "~~", **kwargs)
            expected = template.indented "~~" * level
            expect(actual).to eq expected
          end
        end

        yield(self) if block_given?
      end
    end

    def self.reindents_ambiguous(template_str, **kwargs)
      reindents(template_str, " ambigious\n      ", **kwargs) do |context|
        context.it "cannot reindent \"#{template_str}\"" do
          expect do
            reindent(template_str, 3, "~~")
          end.to raise_error(/ambiguous/i)
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
    reindents_ambiguous \
      "|def python_fn():
       |  pass",
      handle_ambiguity: described_class::Ambiguity.adjust_by(2)

    reindents_ambiguous \
      "|def python_fn():
       |  if True:
       |    pass",
      handle_ambiguity: described_class::Ambiguity.adjust_by(2)

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
    reindents_ambiguous \
      "|def ruby_fn
       |end",
      handle_ambiguity: described_class::Ambiguity.ignore

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
