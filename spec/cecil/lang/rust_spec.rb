require "cecil/lang/rust"

module Unicode
  module_function

  ASCII_CTRL_CODEPOINTS = (0..31).to_a.to_a.freeze
  ASCII_PRINTABLE_CODEPOINTS = (32..127).to_a.freeze

  def inspect_int(int)
    chr = int.chr(Encoding::UTF_8)

    # specific known characters
    case chr
    when '"', "\\" then return chr
    when "\0" then return '\0'
    end

    # everything else, use Ruby's inspect
    chr.inspect[1...-1]
  end

  def inspect_str(char) = char.each_codepoint.map { inspect_int(_1) }.join

  def inspect(obj)
    case obj
    in String then inspect_str(obj)
    in Integer then inspect_int(obj)
    in Array then obj.map { inspect(_1) }.join(" ")
    end
  end
end

RSpec.describe Cecil::Lang::Rust do
  it "indents with 4 spaces" do
    code = described_class.generate_string do
      `fn fibonacci() {`[] do
        `recurse()`
      end
    end

    expect(code).to eq <<~CODE
      fn fibonacci() {
          recurse()
      }
    CODE
  end

  it "closes curly braces" do
    code = described_class.generate_string do
      `fn fibonacci() {`[] do
        `do_stuff()`
      end
    end

    expect(code).to eq <<~CODE
      fn fibonacci() {
          do_stuff()
      }
    CODE
  end

  it "closes parens" do
    code = described_class.generate_string do
      `my_func(`[] do
        `value`
      end
    end

    expect(code).to eq <<~CODE
      my_func(
          value
      )
    CODE
  end

  it "closes square brackets" do
    code = described_class.generate_string do
      `let values = vec![`[] do
        `v1,`
        `v2`
      end
    end

    expect(code).to eq <<~CODE
      let values = vec![
          v1,
          v2
      ]
    CODE
  end

  it "does not indent ambigous lines" do
    code = described_class.generate_string do
      `fn my_func() {
      }`
    end

    expect(code).to eq <<~CODE
      fn my_func() {
      }
    CODE
  end

  describe Cecil::Lang::Rust::Helpers do
    include described_class

    describe "#l" do
      it "joins items with ', '" do
        expect(l(%w[a b c])).to eq "a, b, c"
      end

      it "converts inputs to strings" do
        expect(l(["a", "b", :c])).to eq "a, b, c"
      end

      it "removes nils" do
        expect(l(["a", nil, "b", :c])).to eq "a, b, c"
      end

      it "accepts single item" do
        expect(l("a")).to eq "a"
      end

      it "returns empty string when given nil" do
        expect(l(nil)).to eq ""
      end

      it "converts single items to string" do
        expect(l(:c)).to eq "c"
      end
    end

    describe "#s" do
      rs_custom_escaped_codepoints = described_class::CHAR_TO_CUSTOM_ESCAPE_LITERAL.keys.join.each_codepoint.to_a

      # 127 is DEL
      ascii_codepoints_with_escaped_literal_notation =
        Unicode::ASCII_CTRL_CODEPOINTS \
        + [127] \
        - rs_custom_escaped_codepoints

      ascii_ctrl_codepoints_with_custom_escape =
        rs_custom_escaped_codepoints \
        & Unicode::ASCII_CTRL_CODEPOINTS

      # all ascii printable characters except for those with custom escapes or DEL
      ascii_printable_codepoints_with_custom_rs_escape_literal =
        rs_custom_escaped_codepoints \
        & Unicode::ASCII_PRINTABLE_CODEPOINTS

      ascii_printable_chars_we_dont_escape =
        Unicode::ASCII_PRINTABLE_CODEPOINTS \
        - ascii_printable_codepoints_with_custom_rs_escape_literal \
        - ascii_codepoints_with_escaped_literal_notation

      some_emoji = {
        "😉" => '\\u{1f609}',
        "🇺🇦" => '\\u{1f1fa}\\u{1f1e6}'
      }

      describe "ascii characters with escape notation in Rust" do
        described_class::CHAR_TO_CUSTOM_ESCAPE_LITERAL.each do |char, escaped|
          it "escapes #{Unicode.inspect(char)} as #{escaped}" do
            expect(s(char)).to eq escaped
          end
        end
      end

      describe "ascii control characters and DEL (except for #{Unicode.inspect(ascii_ctrl_codepoints_with_custom_escape)})" do # rubocop:disable Layout/LineLength
        specify "are escaped as unicode code points" do
          raw = ascii_codepoints_with_escaped_literal_notation.map(&:chr).join
          esc = ascii_codepoints_with_escaped_literal_notation.map { "\\u{#{_1.to_s(16)}}" }.join

          expect(s(raw)).to eq esc
        end
      end

      describe "ascii printable characters (except for #{Unicode.inspect(ascii_printable_codepoints_with_custom_rs_escape_literal)})" do # rubocop:disable Layout/LineLength
        specify "are not escaped" do
          raw = ascii_printable_chars_we_dont_escape.map(&:chr).join
          expect(s(raw)).to eq raw
        end
      end

      some_emoji.each do |char, escaped|
        it "escapes #{char.inspect[1...-1]} as #{escaped}" do
          expect(s(char)).to eq escaped
        end
      end
    end

    describe "#rs" do
      examples = {
        true => "true",
        false => "false",

        "hello world" => "\"hello world\"",
        "\n\0" => "\"\\n\\0\"",
        1.chr => "\"\\u{1}\"",

        -2 => "-2",
        0 => "0",
        2 => "2",

        -3.0 => "-3.0",
        0.0 => "0.0",
        3.0 => "3.0"
      }

      examples.each do |input, expected|
        it "converts #{input.inspect} to #{expected.inspect}" do
          expect(rs(input)).to eq expected
        end
      end
    end
  end
end
